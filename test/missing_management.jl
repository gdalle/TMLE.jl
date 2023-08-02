module TestMissingValues

using Test
using StableRNGs
using Random
using MLJLinearModels
using TMLE
using CategoricalArrays
using DataFrames

include("helper_fns.jl")

function dataset_with_missing_and_ordered_treatment(;n=1000)
    rng = StableRNG(123)
    W = rand(rng, n)
    T = rand(rng, [0, 1, 2], n)
    y = T + 3W + randn(rng, n)
    dataset = DataFrame(W = W, T = categorical(T, ordered=true, levels=[0, 1, 2]), y = y)
    allowmissing!(dataset)
    dataset.W[1:5] .= missing
    dataset.T[6:10] .= missing
    dataset.y[11:15] .= missing
    return dataset
end


@testset "Test nomissing" begin
    dataset = dataset_with_missing_and_ordered_treatment(;n=100)
    # filter missing rows based on W column
    filtered = TMLE.nomissing(dataset, [:W])
    @test filtered.W == dataset.W[6:end]
    # filter missing rows based on W, T columns
    filtered = TMLE.nomissing(dataset, [:W, :T])
    @test filtered.W == dataset.W[11:end]
    @test filtered.T == dataset.T[11:end]
    # filter all missing rows
    filtered = TMLE.nomissing(dataset)
    @test filtered.W == dataset.W[16:end]
    @test filtered.T == dataset.T[16:end]
    @test filtered.y == dataset.y[16:end]
end

@testset "Test estimation with missing values and ordered factor treatment" begin
    dataset = dataset_with_missing_and_ordered_treatment(;n=1000)
    Ψ = ATE(
        outcome=:y, 
        confounders=[:W], 
        treatment=(T=(case=1, control=0),))
    η_spec = NuisanceSpec(LinearRegressor(), LogisticClassifier(lambda=0))
    tmle_result, cache = tmle(Ψ, η_spec, dataset; verbosity=0)
    test_coverage(tmle_result, 1)
    test_fluct_decreases_risk(cache; outcome_name=:y)
end

end

true