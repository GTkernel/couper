import sys
from get_splitable_layers.get_layers import getLayers
from referee.methods import LayerFilter

pbfile = sys.argv[1]
spfile = sys.argv[2]
percent = int(sys.argv[3])
# find all splitting points
num_layer, sp_layers = getLayers(pbfile)

referee = LayerFilter(spfile, num_layer, sp_layers, percent)

referee.Run()

print num_layer
