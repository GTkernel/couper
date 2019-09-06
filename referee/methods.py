import sys

RAW=55000
TO_REAL_A = 4
TO_REAL_B = 300

class LayerFilter:
    
    def __init__(self, model_name, num_layer, layers, percent):
        self.model_name = model_name
        self.num_layer = num_layer
        self.layers = layers
        self.percent = percent

    def Run(self):
        bf_file = open(self.model_name+"_bf", "w")
        dd_file = open(self.model_name+"_dd", "w")
        for layer in self.layers:
            #layer_ids.write(str(layer[0])+"\n")
            real_size = TO_REAL_A*layer[2]+TO_REAL_B
#            bf_file.write(str(layer[0])+" "+layer[1]+" "+str(real_size)+"\n")
#            print real_size
#            print layer[1]
            bf_file.write(layer[1]+"\n")
            if self.percent*RAW >= real_size:
                dd_file.write(str(layer[0])+" "+layer[1]+"\n")

        bf_file.close()
        dd_file.close()
