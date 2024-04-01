###############################################################################
## General Utilities
###############################################################################

reuse_string(estimand) = string("Reusing estimate for: ", string_repr(estimand))
fit_string(estimand) = string("Estimating: ", string_repr(estimand))

key(estimand, estimator) = (key(estimand), key(estimator))

unique_sorted_tuple(iter) = Tuple(sort(unique(Symbol(x) for x in iter)))

choose_initial_dataset(dataset, nomissing_dataset, resampling::Nothing) = dataset
choose_initial_dataset(dataset, nomissing_dataset, resampling) = nomissing_dataset

selectcols(data, cols) = data |> TableOperations.select(cols...) |> Tables.columntable

function logit!(v)
    for i in eachindex(v)
        v[i] = logit(v[i])
    end
end

function nomissing(table)
    sch = Tables.schema(table)
    for type in sch.types
        if nonmissingtype(type) != type
            coltable = table |> 
                       TableOperations.dropmissing |> 
                       Tables.columntable
            return NamedTuple{keys(coltable)}([disallowmissing(col) for col in coltable])
        end
    end
    return table
end

function nomissing(table, columns)
    columns = selectcols(table, columns)
    return nomissing(columns)
end

function indicator_values(indicators, T)
    indic = zeros(Float64, nrows(T))
    for (index, row) in enumerate(Tables.namedtupleiterator(T))
        indic[index] = get(indicators, values(row), 0.)
    end
    return indic
end

expected_value(ŷ::UnivariateFiniteVector{<:Union{OrderedFactor{2}, Multiclass{2}}}) = pdf.(ŷ, levels(first(ŷ))[2])
expected_value(ŷ::AbstractVector{<:Distributions.UnivariateDistribution}) = mean.(ŷ)
expected_value(ŷ::AbstractVector{<:Real}) = ŷ

training_expected_value(Q::Machine, dataset) = expected_value(predict(Q, dataset))

function counterfactualTreatment(vals, T)
    Tnames = Tables.columnnames(T)
    n = nrows(T)
    NamedTuple{Tnames}(
            [categorical(repeat([vals[i]], n), levels=levels(Tables.getcolumn(T, name)), ordered=isordered(Tables.getcolumn(T, name)))
                            for (i, name) in enumerate(Tnames)])
end

last_fluctuation(cache) = cache[:last_fluctuation]

function last_fluctuation_epsilon(cache)
    mach = last_fluctuation(cache).outcome_mean.machine
    fp = fitted_params(fitted_params(mach).fitresult.one_dimensional_path)
    return fp.coef
end

"""
    default_models(;Q_binary=LinearBinaryClassifier(), Q_continuous=LinearRegressor(), G=LinearBinaryClassifier()) = (

Create a NamedTuple containing default models to be used by downstream estimators. 
Each provided model is prepended (in a `MLJ.Pipeline`) with an `MLJ.ContinuousEncoder`.

By default:
    - Q_binary is a LinearBinaryClassifier
    - Q_continuous is a LinearRegressor
    - G is a LinearBinaryClassifier

# Example

The following changes the default `Q_binary` to a `LogisticClassifier` and provides a `RidgeRegressor` for `special_y`. 

```julia
using MLJLinearModels
models = (
    special_y = RidgeRegressor(), 
    default_models(Q_binary=LogisticClassifier())...
)
```

"""
default_models(;Q_binary=LinearBinaryClassifier(), Q_continuous=LinearRegressor(), G=LinearBinaryClassifier()) = (
    Q_binary_default = with_encoder(Q_binary),
    Q_continuous_default = with_encoder(Q_continuous),
    G_default = with_encoder(G)
)

is_binary(dataset, columnname) = Set(skipmissing(Tables.getcolumn(dataset, columnname))) == Set([0, 1])

function satisfies_positivity(Ψ, freq_table; positivity_constraint=0.01)
    for jointlevel in joint_levels(Ψ)
        if !haskey(freq_table, jointlevel) || freq_table[jointlevel] < positivity_constraint
            return false
        end
    end
    return true
end

satisfies_positivity(Ψ, freq_table::Nothing; positivity_constraint=nothing) = true

function frequency_table(dataset, colnames)
    iterator = zip((Tables.getcolumn(dataset, colname) for colname in sort(collect(colnames)))...)
    counts = groupcount(x -> x, iterator) 
    for key in keys(counts)
        counts[key] /= nrows(dataset)
    end
    return counts
end