nn_model = @compact(
    flatten1 = FlattenRowMajor(),
) do x
    out = flatten1(x)
    @return out
end

for i in 1:3
    rng = StableRNG(i)
    ps, st = Lux.setup(rng, nn_model)
    input = rand(rng, 5, 4, 3, 1)
    output = nn_model(input, ps, st)[1]
    df_input = _array_to_tidy(input; mapping = [1 => 4, 2 => 3, 2 => 1, 3 => 2])
    df_output = _array_to_tidy(output; mapping = [1 => 2, 2 => 1])
    CSV.write(joinpath(@__DIR__, "..", "net_input_$i.tsv"), df_input, delim = '\t')
    CSV.write(joinpath(@__DIR__, "..", "net_output_$i.tsv"), df_output, delim = '\t')
end
write_yaml(joinpath(@__DIR__, ".."); ps = false)
