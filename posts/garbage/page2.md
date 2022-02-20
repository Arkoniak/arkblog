@def title = "Franklin Example"
@def hasmath = true
@def hascode = true

\tableofcontents

# Simulations

<span style="color:red">this text is red</span>

So here we go with business as usual and suddenly ~~~<span style="color:red; background-color:#F0F0F0">text in red</span> or <span style="color:blue; background-color:#F0F0F0">blue?</span>~~~ BAM!!

# Inital version

```
using Statistics

struct Experiment
    p::Float64
    n::Int
    theta::Float64
end

function run(ex)
    val = 1.0
    for i in 1:ex.n
        val *= rand() < ex.p ? 1 + ex.theta : 1 - ex.theta
    end
    
    return val
end
```

Now we can create and run our first experiment

```
julia> ex = Experiment(0.55, 100, 0.05)
julia> run(ex)
0.5912653691771662
```

```
function sim(ex, N = 10_000)
    res = []
    for _ in 1:N
        push!(res, run(ex))
    end
    
    return quantile(res, (0.05, 0.5, 0.95))
end
```

# Tidying up


# Optimization

## Optimizing single run

## Optimizing whole simulation

# Golden Section

# Results
