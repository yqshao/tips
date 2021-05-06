#!/usr/bin/env nextflow
nextflow.enable.dsl=2
import nextflow.extension.CH
import nextflow.script.ScriptBinding.ParamsMap
import groovyx.gpars.dataflow.operator.ChainWithClosure
import groovyx.gpars.dataflow.operator.CopyChannelsClosure
import static nextflow.extension.DataflowHelper.newOperator

// create a channel that iteratives emits elements from
// source, the channel stops when:
// - source stops
// - condition met for all elements from source
//
// TODO: This implementation is not optimal, better if the "result" for each
// source element can be emitted before all iteration ends, and the syntax may
// be improved.

def iterUntil(source, condition) {
    source0 = source.unique{it[0]}.map{[it[0]+[iter:0], it[1]]}
    feedback = CH.create()
    source0.count()
        .combine(feedback.filter{condition(it)}
                 .unique{it[0].findAll{k,v->k!='iter'}})
        .reduce(0){a,b->
            if(a+1==b[0]){CH.close0(feedback)}; return a+1}
    result = source0.mix(feedback.filter{!condition(it)}
                         .map{[it[0].findAll{k,v->k!='iter'}+[iter:it[0].iter+1], it[1]]})
    return [result, feedback]
}

def setNext(source, target) {
    newOperator([source.createReadChannel()], [target],
                new ChainWithClosure(new CopyChannelsClosure()))
}

// copy ParamsMap with updates, see
// https://github.com/nextflow-io/nextflow/issues/2084
def getParams(defaults, updates){
    (defaults+updates).findAll {k,v -> (k in defaults.keySet()) | (k=='meta') }
}
