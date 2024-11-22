#=
    Hard-coded likelihood and simulated values for test case 001
=#

using FiniteDifferences, YAML
include(joinpath(@__DIR__, "models.jl"))
include(joinpath(@__DIR__, "..", "..", "..", "src", "julia", "helper.jl"))
Random.seed!(123)

function compute_nllh(x, oprob::ODEProblem, solver, measurements::DataFrame; abstol = 1e-9,
                      reltol = 1e-9)::Real
    input_data = [[10.0, 20.0], [1.0, 1.0]]

    nllh, σ = 0.0, 0.05
    for (i, cond) in pairs(["cond1", "cond2"])
        mcond = measurements[measurements[!, :simulationConditionId] .== cond, :]
        mprey = mcond[mcond[!, :observableId] .== "prey", :measurement]
        mpredator = mcond[mcond[!, :observableId] .== "predator", :measurement]
        tsave = unique(mcond.time)

        nnout = nn_model(input_data[i], x.p_net1, st)[1]
        _p = convert.(eltype(x), ComponentArray(oprob.p))
        _p[1:3] .= x[1:3]
        _p[4] = nnout[1]
        _oprob = remake(oprob, p = _p)
        sol = solve(_oprob, solver, abstol = abstol, reltol = reltol, saveat = tsave)
        prey, predator = sol[1, :], sol[2, :]

        for j in eachindex(mprey)
            nllh += log(σ) + 0.5 * log(2π) + 0.5 * (mprey[j] - prey[j])^2 / σ^2
        end
        for j in eachindex(mpredator)
            nllh += log(σ) + 0.5 * log(2π) + 0.5 * (mpredator[j] - predator[j])^2 / σ^2
        end
    end
    return nllh
end

## Parameter estimation problem setup
measurements = CSV.read(joinpath(@__DIR__, "..", "petab", "measurements.tsv"), DataFrame)
# Objective function
xmech = (α = 1.3, δ = 1.8, β = 0.9)
x = ComponentArray(merge(xmech, (p_net1=pnn,)))
# Read neural net parameters, and assign to x
include(joinpath(@__DIR__, "..", "..", "..", "src", "julia", "helper.jl"))
df_ps_nn = CSV.read(joinpath(@__DIR__, "..", "petab", "parameters_nn.tsv"), DataFrame)
set_ps_net!(x.p_net1, df_ps_nn, :net1, nn_model)

## Compute model values
_f = (x) -> compute_nllh(x, oprob, Vern9(), measurements; abstol = 1e-12, reltol = 1e-12)
llh = _f(x) .* -1
# High order finite-difference scheme
llh_grad = FiniteDifferences.grad(central_fdm(5, 1), _f, x)[1] .* -1
# Simulated values, order as in measurements
_p = (α = 1.3, δ = 1.8, β = 0.9, γ = nn_model([10.0, 20.0], x.p_net1, st)[1][1])
_oprob = remake(oprob, p = _p)
sol = solve(_oprob, Vern9(), abstol = 1e-9, reltol = 1e-9,
            saveat = unique(measurements.time))
simulated_values1 = vcat(sol[1, :], sol[2, :])
_p = (α = 1.3, δ = 1.8, β = 0.9, γ = nn_model([1.0, 1.0], x.p_net1, st)[1][1])
_oprob = remake(oprob, p = _p)
sol = solve(_oprob, Vern9(), abstol = 1e-9, reltol = 1e-9,
            saveat = unique(measurements.time))
simulated_values2 = vcat(sol[1, :], sol[2, :])
simulated_values = vcat(simulated_values1, simulated_values2)

## Write values for saving to file
# YAML problem file
solutions = Dict(:llh => llh,
                 :tol_llh => 1e-3,
                 :tol_grad_llh => 1e-1,
                 :tol_simulations => 1e-3,
                 :grad_llh_files => ["grad_llh.tsv"],
                 :simulation_files => ["simulations.tsv"])
YAML.write_file(joinpath(@__DIR__, "..", "solutions.yaml"), solutions)
# Simulated values
simulations_df = deepcopy(measurements)
rename!(simulations_df, "measurement" => "simulation")
simulations_df.simulation .= simulated_values
CSV.write(joinpath(@__DIR__, "..", "simulations.tsv"), simulations_df, delim = '\t')
# Gradient values
df_net = deepcopy(df_ps_nn)
df_net.value .= llh_grad.p_net1
df_mech = DataFrame(parameterId = ["alpha", "delta", "beta"],
                    value = llh_grad[1:3])
df_grad = vcat(df_mech, df_net)
CSV.write(joinpath(@__DIR__, "..", "grad_llh.tsv"), df_grad, delim = '\t')

# Write problem yaml
problem_yaml = Dict(
    :format_version => 1,
    :parameter_file => "parameters_ude.tsv",
    :problems => [Dict(
        :condition_files => ["conditions.tsv"],
        :measurement_files => ["measurements.tsv"],
        :observable_files => ["observables.tsv"],
        :sbml_files => ["lv.xml"],
        :mapping_tables => "mapping_table.tsv")],
    :extensions => Dict(
        :petab_sciml => Dict(
            :net_files => ["net1.yaml"],
            :hybridization => Dict(
                :net1 => Dict(
                    :input => "pre_ode",
                    :output => "pre_ode")))))
YAML.write_file(joinpath(@__DIR__, "..", "petab", "problem_ude.yaml"), problem_yaml)
