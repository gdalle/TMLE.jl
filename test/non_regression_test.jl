module NonRegressionTest

using Test
using TMLE
using CSV
using DataFrames 
using CategoricalArrays
using MLJGLMInterface

@testset "Test ATE on perinatal dataset." begin
    # This is a non-regression test which was checked against the R tmle3 package
    dataset = CSV.read(joinpath("data", "perinatal.csv"), DataFrame, missingstring=["", "NA"])
    confounders = [:apgar1, :apgar5, :gagebrth, :mage, :meducyrs, :sexn]
    dataset.haz01 = categorical(dataset.haz01)
    dataset.parity01 = categorical(dataset.parity01)
    for col in confounders
        dataset[!, col] = float(dataset[!, col])
    end
    scm = StaticConfoundedModel(
        :haz01, :parity01, confounders,
        outcome_model = TreatmentTransformer() |> LinearBinaryClassifier(),
        treatment_model = LinearBinaryClassifier()
    )
    Ψ = ATE(scm=scm, outcome=:haz01, treatment=(parity01=(case=1, control=0),))

    result, fluctuation_mach = tmle(Ψ, dataset, threshold=0.025, verbosity=0)
    l, u = confint(OneSampleTTest(result.tmle))
    @test TMLE.estimate(result.tmle) ≈ -0.185533 atol = 1e-6
    @test l ≈ -0.279246 atol = 1e-6
    @test u ≈ -0.091821 atol = 1e-6
end

end

true