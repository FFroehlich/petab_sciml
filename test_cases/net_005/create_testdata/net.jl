nn_model = @compact(
    layer1 = Conv((5, 5, 5), 1 => 2; cross_correlation = true),
    layer2 = Conv((5, 4, 3), 2 => 1; cross_correlation = true)
) do x
    embed = layer1(x)
    out = layer2(embed)
    @return out
end

for i in 1:3
    rng = StableRNG(i)
    ps, st = Lux.setup(rng, nn_model)
    input = rand(rng, 9, 8, 7, 1, 1)
    output = nn_model(input, ps, st)[1]
    df_ps = nn_ps_to_tidy(nn_model, ps, :net)
    # PyTorch does not need the batch
    df_input = _array_to_tidy(input[:, :, :, :, 1]; mapping = [1 => 4, 2 => 1, 3 => 2, 4 => 3])
    df_output = _array_to_tidy(output[:, :, :, :, 1];  mapping = [1 => 4, 2 => 1, 3 => 2, 4 => 3])
    CSV.write(joinpath(@__DIR__, "..", "net_ps_$i.tsv"), df_ps, delim = '\t')
    CSV.write(joinpath(@__DIR__, "..", "net_input_$i.tsv"), df_input, delim = '\t')
    CSV.write(joinpath(@__DIR__, "..", "net_output_$i.tsv"), df_output, delim = '\t')
end
write_yaml(joinpath(@__DIR__, ".."))
