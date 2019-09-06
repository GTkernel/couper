import tensorflow as tf
from tensorflow.python.platform import gfile
import sys

def getLayers(model_name):

    cuttable = []
    check_ops = set()
    num_ops = 0

    def _put_in_cuttable(op):

        total_size = 1
        for dim in op.outputs[0].shape.dims:
            if dim.value:
                total_size*=dim.value

        cuttable.insert(0, (num_ops, op.name[7:], total_size))
    
    with tf.Session() as session:
        with gfile.FastGFile(model_name, 'rb') as f:
            graph_def = tf.GraphDef()
            graph_def.ParseFromString(f.read())
            g_in = tf.import_graph_def(graph_def)

    ops = session.graph.get_operations()
    
    while len(ops) > 0: 
        op = ops.pop()
        if op.type == 'Const' or op.type == 'Identity':
            continue
        else:
            #print(op.name)
            num_ops +=1

        if not check_ops : # if check_ops is empty
            _put_in_cuttable(op)
        elif op in check_ops:
            if len(check_ops) == 1:
                _put_in_cuttable(op)
            check_ops.remove(op)
        # add upstream in check_ops
        for in_tensor in op.inputs:
            if in_tensor.op.type != 'Const' and in_tensor.op.type != 'Identity':
                check_ops.add(in_tensor.op)
        
    session.close()
    # outfile.write('total ops: '+ str(num_ops)+'\ncuttable: '+str(len(cuttable[1:-1]))+'\n');
    # outfile.write('\n'.join(op[0]+" "+str(op[1]) for op in cuttable[1:-1]))
    return num_ops, cuttable[1:-1]

