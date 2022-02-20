@def title = "Manual Union-Splitting"
@def hasmath = false
@def hascode = true
@def date = Date(2020, 11, 21)

# Manual Union-Splitting

Recently there was an interesting discussion on Julia [Zulip](https://julialang.zulipchat.com/#narrow/stream/225542-helpdesk/topic/Dispatching.20over.20an.20abstract.20iterable.3F) regarding working with containers that contain elements of different types. The problem is that if the type of elements too broad, then Julia can't specialize and starts to allocate and perform badly. It can be solved by using the [manual union-splitting](https://julialang.org/blog/2018/08/union-splitting/) technique.

Let's consider the following example

```
using BenchmarkTools
using Underscores
using StableRNGs

abstract type Foo end

struct Bar1 <: Foo
    x::Float64
end
f(b::Bar1) = b.x

struct Bar2 <: Foo
    x::Float64
end
f(b::Bar2) = b.x^2

struct Bar3 <: Foo
    x::Float64
end
f(b::Bar3) = b.x^3

struct Bar4 <: Foo
    x::Float64
end
f(b::Bar4) = b.x^4

struct Bar5 <: Foo
    x::Float64
end
f(b::Bar5) = b.x^5

rng = StableRNG(2020)
v = @_ zip(rand(rng, (Bar1, Bar2, Bar3, Bar4, Bar5), 1000), rand(rng, 1000)) |> map(_[1](_[2]), __)
```

Now we have 5 different subtypes of an abstract type `Foo` and function `f` which has different versions for each of the `Bar` types.

If we try to do any calculations with `v` then we can be disappointed with a huge amount of allocations and relatively low speed

```
function g1(vec)
    res = 0.0
    for b in vec
        res += f(b)
    end
    return res
end

julia> @btime g1($v)
  80.863 μs (2000 allocations: 31.25 KiB)
```

2000 allocations, that's a lot. How can we make it run faster? The aforementioned manual union splitting is really helping here and it has this rather unusual and somewhat unexpected form

```
function g2(vec)
    res = 0.0
    for b in vec
        res += if b isa Bar1
            f(b)
        elseif b isa Bar2
            f(b)
        elseif b isa Bar3
            f(b)
        elseif b isa Bar4
            f(b)
        elseif b isa Bar5
            f(b)
        end
    end

    return res
end
```
```
julia> @assert g2(v) ≈ g1(v)
julia> @btime g2($v) # 18.550 μs (0 allocations: 0 bytes)
```
This is much better, the number of allocations fall to zero, and the time boost is 4x.

It is interesting to understand how it is working. The easiest way to see it is to use `@code_warntype` macro
```
julia> @code_warntype g1(v)
Variables
  #self#::Core.Const(g1)
  vec::Vector{Foo}
  @_3::Union{Nothing, Tuple{Foo, Int64}}
  res::Any
  b::Foo

Body::Any
1 ─       (res = 0.0)
│   %2  = vec::Vector{Foo}
│         (@_3 = Base.iterate(%2))
│   %4  = (@_3 === nothing)::Bool
│   %5  = Base.not_int(%4)::Bool
└──       goto #4 if not %5
2 ┄ %7  = @_3::Tuple{Foo, Int64}::Tuple{Foo, Int64}
│         (b = Core.getfield(%7, 1))
│   %9  = Core.getfield(%7, 2)::Int64
│   %10 = res::Any
│   %11 = Main.f(b)::Any
│         (res = %10 + %11)
│         (@_3 = Base.iterate(%2, %9))
│   %14 = (@_3 === nothing)::Bool
│   %15 = Base.not_int(%14)::Bool
└──       goto #4 if not %15
3 ─       goto #2
4 ┄       return res
```

and at union-splitting function we can see

```
julia> @code_warntype g2(v)
Variables
  #self#::Core.Const(g2)
  vec::Vector{Foo}
  @_3::Union{Nothing, Tuple{Foo, Int64}}
  res::Float64
  b::Foo
  @_6::Union{Nothing, Float64}
  @_7::Union{Nothing, Float64}
  @_8::Union{Nothing, Float64}
  @_9::Union{Nothing, Float64}
  @_10::Union{Nothing, Float64}

Body::Float64
1 ──       (res = 0.0)
│    %2  = vec::Vector{Foo}
│          (@_3 = Base.iterate(%2))
│    %4  = (@_3 === nothing)::Bool
│    %5  = Base.not_int(%4)::Bool
└───       goto #19 if not %5
2 ┄─ %7  = @_3::Tuple{Foo, Int64}::Tuple{Foo, Int64}
│          (b = Core.getfield(%7, 1))
│    %9  = Core.getfield(%7, 2)::Int64
│    %10 = res::Float64
│    %11 = (b isa Main.Bar1)::Bool
└───       goto #4 if not %11
3 ──       (@_6 = Main.f(b::Bar1))
└───       goto #17
4 ── %15 = (b isa Main.Bar2)::Bool
└───       goto #6 if not %15
5 ──       (@_7 = Main.f(b::Bar2))
└───       goto #16
6 ── %19 = (b isa Main.Bar3)::Bool
└───       goto #8 if not %19
7 ──       (@_8 = Main.f(b::Bar3))
└───       goto #15
8 ── %23 = (b isa Main.Bar4)::Bool
└───       goto #10 if not %23
9 ──       (@_9 = Main.f(b::Bar4))
└───       goto #14
10 ─ %27 = (b isa Main.Bar5)::Bool
└───       goto #12 if not %27
11 ─       (@_10 = Main.f(b::Bar5))
└───       goto #13
12 ─       (@_10 = nothing)
13 ┄       (@_9 = @_10)
14 ┄       (@_8 = @_9)
15 ┄       (@_7 = @_8)
16 ┄       (@_6 = @_7)
17 ┄ %36 = @_6::Union{Nothing, Float64}
│          (res = %10 + %36)
│          (@_3 = Base.iterate(%2, %9))
│    %39 = (@_3 === nothing)::Bool
│    %40 = Base.not_int(%39)::Bool
└───       goto #19 if not %40
18 ─       goto #2
19 ┄       return res
```

As we can see, in the first version of the function, the compiler gave up rather quickly and decided that the returning type of function `f` is `Any`. As a result, we get a lot of boxing and unboxing with many allocations and low speed. On the other hand, when we do manual union splitting compiler knows that it should call a specialized version of the function and so it runs very fast.

Unfortunately, if we try to add a fallback branch to `if`, then we will lose most of the speedup.

```
function g3(vec)
    res = 0.0
    for b in vec
        res += if b isa Bar1
            f(b)
        elseif b isa Bar2
            f(b)
        elseif b isa Bar3
            f(b)
        else
            f(b)
        end
    end

    return res
end

julia> @btime g3($v) # 52.615 μs (2000 allocations: 31.25 KiB)
  54.127 μs (2000 allocations: 31.25 KiB)
```

but sometimes it can be helped. For example in this case, we know, that the resulting variable has `Float64` type, so we can annotate the output of function `f` accordingly
```
function g4(vec)
    res = 0.0
    for b in vec
        res += if b isa Bar1
            f(b)
        elseif b isa Bar2
            f(b)
        elseif b isa Bar3
            f(b)
        else
            f(b)::Float64
        end
    end

    return res
end

julia> @btime g4($v)
  27.198 μs (391 allocations: 6.11 KiB)
```
It is not perfect, but good compromise between speed and flexibility.

In the end I want to add Tim Holy explanation, how it differs from usual dynamic dispatch and why it is so efficient.

> Here's an analogy that helps only if you remember the old days when we looked up phone numbers in a book. Dynamic dispatch is like "here's the phone book, look up the number by the name of the person you're trying to call" and you start flipping through the "S" section. Union-splitting is like having someone print out a list of the 5 people you call most frequently and post it right next to your phone.

> To be a little more precise and technical: when Julia compares concrete types, it's literally a pointer comparison: does 0x00007fa0d702c0c0 equal 0x00007fa0d74d7770? That's just a CPU cycle or so. In contrast, if Julia has to figure out what method to call, and one of your methods is written for arguments (a::AbstractVector{T} where T<:Real, b::AbstractString), then the process of deciding whether the types fit is vastly more complicated: you have to engage the whole subtyping machinery. That's very well optimized machinery, but there's no way even in principle to make it as cheap as a single pointer comparison. Moreover, if you don't know in advance which method will match, there's a chance you'll have to do this comparison for many method candidates, in the worst case the entire list of methods.

> When it's complicated, then there's only one way to save the time it takes to do the lookup: to do it when the method is compiled. That happens automatically for you when Julia can infer concrete types, but in cases like the one we're discussing it's not possible even in principle to do so. This manual union-splitting solves the problem in one or two ways. First, if your isa comparisons are precise enough to determine a unique method, Julia can save the runtime cost of flipping through the pages of the phone book and do that lookup at compile time---that's essentially like printing out your "most frequently called numbers" list. Second, if your isa comparisons are against a concrete type (not an abstract type, not a Union), then Julia will reduce those type comparisons to a single pointer check---that's like making it so you can recognize which of your favorite numbers you need to call with a glance, and not have to fire up something analogous to regex machinery to match the name of the person. You get real benefit from each of these, and when both apply it's really fast.
