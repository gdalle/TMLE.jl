module TestReport

using Test
using TMLE
using MLJ
using StableRNGs

@testset "Test influencecurve" begin
    @test TMLE.influencecurve([1, 1, 1], [1, 0, 1], [0.8, 0.1, 0.8], [0.8, 0.2, 0.8], 1) == 
        [0.0
        -0.9
        0.0]
end

@testset "Test summary" begin
    query = Query((t=0,), (t=1,))
    r1 = TMLE.QueryReport(query, [1, 2, 3, 4], 1, 0.8)
    s1 = briefreport(r1)
    @test s1.query == query
    @test s1.pvalue ≈ 5.88e-8 atol=1e-2
    @test s1.confint[1] ≈ 2.234 atol=1e-2
    @test s1.confint[2] ≈ 4.765 atol=1e-2
    @test s1.estimate == 1.0
    @test s1.initial_estimate == 0.8
    @test s1.stderror ≈ 0.645 atol=1e-2
    @test s1.mean_inf_curve == 2.5

end

@testset "Test Misc" begin
    rng = StableRNG(123)
    n = 100
    T = (t₁=categorical(sample(rng, ["CG", "CC"], Weights([0.7, 0.3]), n)),
         t₂=categorical(sample(rng, ["AT", "AA"], Weights([0.6, 0.4]), n)))
    W = (w₁=rand(rng, n), w₂=rand(rng, n))
    y = categorical(rand(rng, Bernoulli(0.3), n))

    queries = [
        Query(case=(t₁="CC", t₂="AT"), control=(t₁="CG", t₂="AA"), name="Query1"),
        Query(case=(t₁="CG", t₂="AT"), control=(t₁="CC", t₂="AA"), name="Query2")
    ]
    Q̅ = ConstantClassifier()
    G = FullCategoricalJoint(ConstantClassifier())
    F = LinearBinaryClassifier(fit_intercept=false, offsetcol=:offset)

    tmle = TMLEstimator(Q̅, G, queries...)

    mach = machine(tmle, T, W, y)
    fit!(mach, verbosity=0)
    
    queryreports = getqueryreports(mach)
    for (i, qr) in enumerate(queryreports)
        @test qr == getqueryreport(mach, i)
        @test qr isa QueryReport
    end
end
end

true