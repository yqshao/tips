#!/usr/bin/env nextflow

params.pinnParams = 'inputs/pinet.yml'
params.init = 'inputs/init.{lmp,geo}'
params.labeller = 'inputs/{label.lmp,init.geo}'
params.maxIter = 5
params.initSteps = 50000
params.retrainSteps = 1000
params.sampleSteps = 1000
params.seed = 3

converge = { false }
augDs = Channel.create()

process kickoff {
    publishDir 'datasets/init'
    label 'lammps'

    input:
    path inp from Channel.fromPath(params.init).collect()

    output:
    path "train.{tfr,yml}" into initDs
    path "test.{tfr,yml}"

    """
    mpirun -np $task.cpus lmp_mpi -in init.lmp
    tips split prod.dump --log prod.log --emap '1:1,2:8,3:11,4:17' -s 'train:9,test:1'
    """
}

initDs.map({[1, it]})
    .mix(augDs.map {iter,ds -> [iter+1, ds]}
         .until{iter, ds -> iter > params.maxIter})
    .into {ds4train; ds4aug}

process trainner {
    publishDir "models/iter$iter/seed$seed"
    label 'pinn'

    input:
    tuple val(iter), path(dataset, stageAs: 'ds/*') from ds4train
    each seed from Channel.from(1..params.seed)
    each pinnParams from Channel.fromPath(params.pinnParams)

    output:
    tuple val(iter), val(seed), path('model', type:'dir') into models

    script:
    """
    tips split ds/*.yml  -s 'train:8,eval:2' --seed $seed
    pinn_train --model-dir='model' --params=$pinnParams\
        --train-data='train.yml' --eval-data='eval.yml'\
        --cache-data=True --batch-size=10\
        --train-steps=${params.initSteps+(iter-1)*params.retrainSteps}
    """
}

restart = Channel.create()
models4qbc = Channel.create()
models4sample = Channel.create()
models.tap( models4qbc ).filter { it[1] == 1 }.tap( models4sample )
initStruct = Channel.value('').mix(restart)

process sampler {
    publishDir "trajs/iter$iter"
    label 'pinn'

    input:
    tuple val(iter), val(seed), path(model) from models4sample
    file restart from initStruct

    output:
    tuple val(iter), file('aug.traj') into sampledDs
    file 'restart.xyz' into restart

    script:
    """
    #!/usr/bin/env python3
    import pinn
    import tensorflow as tf
    from ase import units
    from ase.io import read, write
    from ase.io.trajectory import Trajectory
    from ase.md import MDLogger
    from ase.md.velocitydistribution import MaxwellBoltzmannDistribution
    from ase.md.nptberendsen import NPTBerendsen

    calc = pinn.get_calc("$model/params.yml")
    atoms = read(${restart.size()>0?"'$restart'":"'${file("inputs/init.xyz")}'"})
    atoms.set_calculator(calc)
    MaxwellBoltzmannDistribution(atoms, 330.*units.kB)
    dt = 0.5 * units.fs
    dyn = NPTBerendsen(atoms, timestep=dt, temperature=330, pressure=1,
                      taut=dt * 100, taup=dt * 1000, compressibility=4.57e-5)
    interval=10 #int(5*units.fs/dt)
    dyn.attach(MDLogger(dyn, atoms, 'aug.log', mode="w"), interval=interval)
    dyn.attach(Trajectory('aug.traj', 'w', atoms).write, interval=interval)
    dyn.run($params.sampleSteps)
    write('restart.xyz', atoms)
    """
}

// [[iter, traj], [iter, seed, model]] -> [iter, seed, traj, model]
toQbc = sampledDs.cross(models4qbc).map {[it[0][0], it[1][1], it[0][1], it[1][2]]}

process label4qbc {
    publishDir "trajs/iter$iter/seed$seed"
    label 'pinn'

    input:
    tuple val(iter), val(seed), path(traj), path(model) from toQbc

    output:
    tuple val(iter), file('label.xyz') into ds4qbc

    script:
    """
    #!/usr/bin/env python3
    import pinn
    import tensorflow as tf
    from ase import units
    from ase.io import read, write

    calc = pinn.get_calc("$model")
    traj = read("$traj", index=':')
    for atoms in traj:
        atoms.set_calculator(calc)
        atoms.get_potential_energy()
    write('label.xyz', traj)
    """
}

process filter {
    label 'pinn'

    input:
    tuple val(iter), path('ds??/label.xyz') from ds4qbc.buffer(size: params.seed).map {[it[0][0], it.collect {it[1]} ]}

    output:
    tuple val({iter}), val({converge()}), path('filtered.{tfr,yml}') into filteredDs

    script:
    """
    tips filter */label.xyz -a qbc -et 'e:0.1,f:0.1' -o filtered
    """
}

process labeller {
    publishDir "dataset/aug$iter"
    label 'lammps'

    input:
    tuple val(iter), path(filterd) from filteredDs.until({it[1]}).map({[it[0],it[2]]})
    path labeller from Channel.fromPath(params.labeller).collect()
    path augDs, stageAs: 'old/*' from ds4aug.map {it[1]}

    output:
    tuple val(iter), path("train.{tfr,yml}") into augDs
    path "test.{tfr,yml}"

    script:
    """
    mkdir aug
    tips convert filtered.yml -o filtered -of 'lammps' --emap '1:1,8:2,11:3,17:4'
    mpirun -np $task.cpus lmp_mpi -in label.lmp
    tips split label.dump --log label.log -s 'aug/train:0.9,test:0.1' --emap '1:1,2:8,3:11,4:17'
    tips merge old/train.yml aug/train.yml -o train
    """
}
