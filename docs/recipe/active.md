# Active workflows

The active learnign recipe provided by TIPS runs active learning loops. The
workflow is controlled by the several subworkflows, the trianing, sampling, and
labelling process. A typical workflow is shown below. Though the flexibility of
this recipe allows for different schemes to be implemented and combiend, see the 
implemented scheme below for details.

=== "Flowchart"

    ```mermaid
    graph LR
    filter([Filter]) --> ds[Dataset]
    ds ------ |End or Next Iter.| qbc
    ref[Reference] --> filter
    ref -----> qbc([QbC])
    inp[Input] ---> train([Train])
    ds --> train
    seeds[Seeds] ---> train
    subgraph QbC Iteration
      train --> model[Model]
      model --> qbc
    end
    ```

=== "main.nf"

    ```groovy
    #!/usr/bin/env nextflow
    
    // A prototypical active learning workflow
    
    nextflow.enable.dsl=2
    nextflow.preview.recursion=true
    
    // Initial Configraitons =================================================================
    params.proj         = 'uniform-nobias'
    params.restart_from = false
    params.init_geo     = 'skel/init/*.xyz'
    params.init_model   = 'models/pils-v5-ekf-v3-*/model'
    params.init_ds      = 'datasets/pils-v5-filtered.{yml,tfr}'
    params.init_time    = 1
    params.init_steps   = 500000
    params.ens_size     = 5
    params.geo_size     = 6
    params.sp_points    = 10
    //========================================================================================
    
    // Imports (publish directories are set here) ============================================
    include { aseMD } from './tips/nextflow/ase.nf' addParams(publish: "$params.proj/emd")
    include { cp2kGenInp } from './tips/nextflow/cp2k.nf' addParams(publish: "$params.proj/cp2k-sp")
    include { cp2k } from './tips/nextflow/cp2k.nf' addParams(publish: "$params.proj/cp2k-sp")
    include { pinnTrain } from './tips/nextflow/pinn.nf' addParams(publish: '$params.proj/models')
    //========================================================================================
    
    // Ietrartion options ====================================================================
    params.ftol         = 0.200
    params.etol         = 0.005
    params.retrain_step = '10000'
    params.label_flags  = '-f asetraj --subsample --strategy uniform --nsample 10'
    // w. force_std:    = '-f asetraj --subsample --strategy sorted --nsample 50'
    params.old_flag     = '--nsample 2400'
    params.new_flag     = '--nsample 600'
    params.acc_fac      = 2.0
    params.min_time     = 1.0
    //========================================================================================
    
    // Model specific flags ==================================================================
    params.train_flags  = '--log-every 1000 --ckpt-every 10000 --batch 1 --max-ckpts 1 --shuffle-buffer 3000'
    params.md_flags     = '--ensemble nvt --T 300 --dt 0.5 --log-every 20'
    // params.md_flags  = '--ensemble nvt --T 300 --t 1 --dt 0.5 --log-every 20 --bias heaviside --kb 1'
    params.cp2k_inp     = './skel/cp2k/singlepoint.inp'
    params.cp2k_aux     = 'skel/cp2k-aux/*'
    //========================================================================================
    ```


