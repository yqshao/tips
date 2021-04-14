#!/usr/bin/env nextflow

// Demo active learning workflow with tips (processes indicated as boxes)
// The workflow is analogous to that of:
// C. Schran, J. Behler & D. Marx, J. Chem. Theory Comput., 2019, 16, 88-99.
//                                            ┌─────────┐
//                                    ┌──────►│Label4Qbc├─────┐
//                                    │       └─────────┘     │
//                                    │            ▲          ▼
// ┌──────┐          ┌─────────┐      │       ┌────┴────┐ ┌──────┐y
// │Lammps├─►InitDs─►│PinnTrain├─►PiNetModel─►│AseSample│ │ErrTol├─►FinalModel
// └──────┘          └─────────┘              └─────────┘ └───┬──┘
//                        ▲                                   │n
//                        │      ┌───────────┐                │
//                      AugDs◄───┤LammpsLabel│◄─Ds2Label◄─────┘
//                               └───────────┘
// Flowchart generated with: https://asciiflow.com/

// Parameters (fixed or from input)
// Lammps Setup (unit: real):
// - InitDs: 100ps, dump every 0.1 ps (1000 points)
// - FF: water (SPC/Fw) + NaCl (Joung-Cheathem)
// - Ensemble: NVT (CSVR barostat)
// ASE Sampling:
// - TimeStep: 0.5 fs, dump every step
// - Ensemble: NPT at 1bar/330K (berendsen barostat)
// PiNN Training:
// - PiNet Parameters taken from the PiNN paper:
//   Y. Shao, M. Hellström, P. D. Mitev, L. Knijff & C. Zhang,
//   J. Chem. Inf. Model., 2020, 60, 3.

params.pinnParams = 'inputs/pinet.yml'
params.init = 'inputs/init.{lmp,geo}'
params.labeller = 'inputs/{label.lmp,init.geo}'

// Adjustable params
params.maxIter = 10          //no. generations
params.seed = 3              //no. models
params.sampleTime = 1        //resample time [ps]
params.initSteps = 200000    //steps for initDs
params.retrainSteps = 50000  //steps for each augDs

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
    tips split prod.dump --log prod.log --units real\
         --emap '1:1,2:8,3:11,4:17' -s 'train:9,test:1'
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
    ${iter>1? "cp -rL ${file("models/iter${iter-1}/seed$seed/model")} model": "mkdir model && cp $pinnParams model/params.yml"}
    pinn_train --model-dir='model' --params='model/params.yml'\
        --train-data='train.yml' --eval-data='eval.yml'\
        --cache-data=True --batch-size=1 --shuffle-buffer=500\
        --train-steps=${params.initSteps+(iter-1)*params.retrainSteps} ${iter==1? "--regen-dress": ""}
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
    steps = int($params.sampleTime*1e3*units.fs/dt)
    dyn = NPTBerendsen(atoms, timestep=dt, temperature=330, pressure=1,
                      taut=dt * 100, taup=dt * 1000, compressibility=4.57e-5)
    interval = 1 #int(0.001e3*units.fs/dt)
    dyn.attach(MDLogger(dyn, atoms, 'aug.log', mode="w"), interval=interval)
    dyn.attach(Trajectory('aug.traj', 'w', atoms).write, interval=interval)
    dyn.run(steps)
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
    import pinn, yaml
    import tensorflow as tf
    from ase import units
    from ase.io import read, write
    with open('$model/params.yml') as f:
        params = yaml.safe_load(f)
        params['model_dir'] = '$model'
    calc = pinn.get_calc(params)
    traj = read("$traj", index=':')
    with open('label.xyz', 'w') as f:
        for atoms in traj:
            atoms.wrap()
            atoms.set_calculator(calc)
            atoms.get_potential_energy()
            write(f, atoms, format='extxyz', append='True')
    """
}

process filter {
    label 'pinn'

    input:
    tuple val(iter), path('ds??/label.xyz') from ds4qbc.buffer(size: params.seed).map {[it[0][0], it.collect {it[1]} ]}

    output:
    tuple val({iter}), val({converge()}), path('filtered.{tfr,yml}') into filteredDs

    script:// energy: 10 meV; force: 100 meV/A
    """
    tips filter */label.xyz -a qbc -et 'e:0.01,f:0.1' -o filtered
    """
}

process labeller {
    publishDir "datasets/aug$iter"
    label 'lammps'

    input:
    tuple val(iter), path(filterd) from filteredDs.until({it[1]}).map({[it[0],it[2]]})
    path labeller from Channel.fromPath(params.labeller).collect()
    path augDs, stageAs: 'old/*' from ds4aug.map {it[1]}

    output:
    tuple val(iter), path("train.{tfr,yml}") into augDs
    path "test.{tfr,yml}"
    file 'restart.xyz' into restart

    script:
    """
    mkdir aug
    tips convert filtered.yml -o filtered -of 'lammps' --emap '1:1,8:2,11:3,17:4'
    mpirun -np $task.cpus lmp_mpi -in label.lmp
    sed -i '/WARNING/d' label.log
    # hotfixes, those are to be implemented in the sampler instead
    python3 << EOF
    import numpy as np
    from ase import Atoms
    from ase.io import write
    from tips.io import read, get_writer
    writer = get_writer('label', format='pinn')
    ds = read('label.dump', log='label.log', units='real', emap='1:1,2:8,3:11,4:17')
    restart = False
    for data in ds:
        if not (np.abs(data['f_data']).max()>10 or data['e_data']>-30):
            writer.add(data)
            if not (np.abs(data['f_data']).max()>4):
                restart = data
    if restart:
        write('restart.xyz', Atoms(restart['elems'], positions=restart['coord'], cell=restart['cell'], pbc=True))
    writer.finalize()
    EOF
    tips split label.yml -s 'aug/train:0.9,test:0.1'
    # --log label.log --units real --emap '1:1,2:8,3:11,4:17'
    tips merge old/train.yml aug/train.yml -o train
    """
}
