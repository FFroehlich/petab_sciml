import torch
import torch.nn as nn
import torch.nn.functional as F
import sys
import os
import pandas as pd

sys.path.insert(1, os.path.join(os.getcwd(), 'mkstd', "examples", "petab_sciml"))
sys.path.insert(1, os.path.join(os.getcwd(), 'test_cases'))
from petab_sciml_standard import Input, MLModel, PetabScimlStandard
from helper import read_array, get_ps_layer

class Net(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.layer1 = nn.Linear(10, 2)
        self.drop = nn.AlphaDropout(0.5)

    def forward(self, input: torch.Tensor) -> torch.Tensor:
        x = self.drop(input)
        out = self.layer1(x)
        return out

# Create a pytorch module, convert it to PEtab SciML, then save it to disk.
dir_save = os.path.join(os.getcwd(), 'test_cases', "net_020")
net = Net()
mlmodel = MLModel.from_pytorch_module(
    module=net, mlmodel_id="model1", inputs=[Input(input_id="input1")]
)
petab_sciml_mlmodel = PetabScimlStandard.model(models=[mlmodel])
PetabScimlStandard.save_data(
    data=petab_sciml_mlmodel, filename=os.path.join(dir_save, "net.yaml")
)

for i in range(1, 4):
    layer_names = ["layer1"]
    for layer_name in layer_names:
        df = pd.read_csv(os.path.join(dir_save, "net_ps_" + str(i) + ".tsv"), delimiter='\t')
        ps_weight = get_ps_layer(df, layer_name, "weight")
        ps_bias = get_ps_layer(df, layer_name, "bias")
        with torch.no_grad():
            layer = getattr(net, layer_name)
            layer.weight[:] = ps_weight
            layer.bias[:] = ps_bias

        # As we have dropout
        df_input = pd.read_csv(os.path.join(dir_save, "net_input_" + str(i) + ".tsv"), delimiter='\t')
        df_output = pd.read_csv(os.path.join(dir_save, "net_output_" + str(i) + ".tsv"), delimiter='\t')
        input = read_array(df_input)
        output_ref = read_array(df_output)
        output = torch.zeros(2)
        for i in range(40000):
            output += net.forward(input)
        output /= 40000
        torch.testing.assert_close(output_ref, output, atol=1e-2, rtol=0.0)

