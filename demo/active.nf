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

// Adjustable params
params.pinnParams = 'inputs/pinet.yml'
params.init = 'inputs/init.{lmp,geo}'
params.labeller = 'inputs/{label.lmp,init.geo}'
params.sampleInit = 'inputs/init.xyz'
params.maxIter = 10          //no. generations
params.seed = 2              //no. models
params.sampleTime = 1        //resample time [ps]
params.initSteps = 200000    //steps for initDs
params.retrainSteps = 50000  //steps for each augDs

// Create the output channels
initDs = Channel.create()   // for training sets (iter, ds)
trainDs = Channel.create()   // for training sets (iter, ds)
models = Channel.create()   // for trained models (iter, seed, modelDir)
trajs = Channel.create()    // for trajs
ckpts = Channel.create()
restart = Channel.create()  // restart for sampling
ds4label = Channel.create() // ds to be labelled
aug4combine = Channel.create() // ds to be labelled

// Connecting the channels
Channel.of(1..params.seed)
    .map{[1, it, file(params.pinnParams)]}
    .mix(ckpts)
    .set{ckpt4train}
Channel.of([2, file(params.sampleInit)])
    .mix(restart.map{iter,restart->[iter+1,restart]})
    .until{it[0]>params.maxIter}
    .set{init4sample}
initDs.map{[1, it]}
    .mix(trainDs)
    .tap{ds4combine}
    .combine(Channel.of(1..params.seed)).map{it -> it[[0,2,1]]}
    .tap{ds4train}
models
    .map{iter, seed, model -> [iter+1, seed, model]}
    .until{it[0]>params.maxIter}
    .tap(ckpts)
    .branch {
        md: it[1]==1
            return [it[0], it[2]]
        other: true}
    .set{model4qbc}
trajs
    .tap{qbcRef}
    .combine(Channel.of(2..params.seed)).map{it -> it[[0,2,1]]}
    .join(model4qbc.other, by: [0,1])
    .set{qbcInp}
ds4combine
    .map{iter,ds -> [iter+1, ds]}
    .until{it[0]>params.maxIter}
    .join(aug4combine)
    .map{iter, old, aug -> [iter, old+aug]}
    .tap(trainDs)

// Inputs for processes
trainInp = ckpt4train.join(ds4train, by: [0,1])
sampleInp = init4sample.join(model4qbc.md)

// Proceses
process kickoff {
    publishDir 'datasets/'
    label 'lammps'

    input:
    path inp from Channel.fromPath(params.init).collect()

    output:
    path "train_1.{tfr,yml}"  into initDs
    path "test_1.{tfr,yml}"

    """
    mpirun -np $task.cpus lmp_mpi -in init.lmp
    tips split prod.dump --log prod.log --units real\
         --emap '1:1,2:8,3:11,4:17' -s 'train_1:9,test_1:1'
    """
}

process trainner {
    publishDir "models/iter$iter/seed$seed"
    stageInMode 'copy'
    label 'pinn'

    input:
    tuple val(iter), val(seed), path(model), path(dataset, stageAs: 'ds/*') from trainInp

    output:
    tuple val(iter), val(seed), path('model/', type:'dir') into models

    script:
    """
    tips split ds/*.yml  -s 'train:8,eval:2' --seed $seed
    [ ! -f model/params.yml ] && { mkdir -p model; cp $model model/params.yml; }
    pinn_train --model-dir='model' --params-file='model/params.yml'\
        --train-data='train.yml' --eval-data='eval.yml'\
        --cache-data=True --batch-size=1 --shuffle-buffer=500\
        --train-steps=${params.initSteps+(iter-1)*params.retrainSteps}\
        ${iter==1? "--regen-dress": ""}
    """
}

process sampler {
    publishDir "trajs/iter$iter/seed1"
    label 'pinn'

    input:
    tuple val(iter), path(init), path(model)  from sampleInp

    output:
    tuple val(iter), file('aug.traj') into trajs

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
    atoms = read("$init")
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
    """
}

process pinnlabel {
    publishDir "trajs/iter$iter/seed$seed"
    label 'pinn'

    input:
    tuple val(iter), val(seed), path(traj), path(model) from qbcInp

    output:
    tuple val(iter), file('label.xyz') into qbcOther

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
    tuple val(iter), path('ds??/*') from qbcRef.mix(qbcOther).groupTuple(size:params.seed)

    output:
    tuple val{iter}, path('filtered.{tfr,yml}') into filteredDs

    script:// energy: 10 meV; force: 100 meV/A
    """
    tips filter ds*/* -a qbc -et 'e:0.01,f:0.1' -o filtered
    """
}

process lmplabel {
    publishDir "datasets/", pattern: "*.{tfr,yml}"
    label 'lammps'

    input:
    tuple val(iter), path(ds) from filteredDs
    path labeller from Channel.fromPath(params.labeller).collect()

    output:
    tuple val(iter), path("train_$iter.{tfr,yml}") into aug4combine
    tuple val{iter}, path('restart.xyz') into restart
    path "test_$iter.{tfr,yml}"

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
        if True:#not (np.abs(data['f_data']).max()>10 or data['e_data']>-30):
            writer.add(data)
            if True:#not (np.abs(data['f_data']).max()>4):
                restart = data
    if restart:
        write('restart.xyz', Atoms(restart['elems'], positions=restart['coord'], cell=restart['cell'], pbc=True))
    writer.finalize()
    EOF
    tips split label.yml -s 'train_$iter:0.9,test_$iter:0.1'
    """
}
