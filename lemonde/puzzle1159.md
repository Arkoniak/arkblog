@def title = "Le Monde puzzle 1159"
@def hascode = true

https://www.r-bloggers.com/2020/10/le-monde-puzzle-1159/

```
function testgroups(n, partition)
    s1 = 0
    s2 = 1
    for i in 1:n
        if partition & 0x1 == 0
            s1 += i
        else
            s2 *= i
        end
        partition = partition >> 1
    end

    return s1 == s2
end

function buildgroups(n, partition)
    s1 = 0
    sump = ()
    prodp = ()
    for i in 1:n
        if partition & 0x1 == 0
            s1 += i
            sump = tuple(sump..., i)
        else
            prodp = tuple(prodp..., i)
        end
        partition = partition >> 1
    end

    return (result = s1, sumpart = sump, prodpart = prodp)
end

# testgroups(5, UInt16(11))
# buildgroups(5, UInt16(11))

function partitions(n)
    p = Progress(2^n)
    for partition in 1:(2^n - 1)
        next!(p)
        if testgroups(n, partition)
            @info "found: " buildgroups(n, partition)
        end
    end
end
```

```
julia> partitions(10)
┌ Info: found:
└   buildgroups(n, partition) = (result = 42, sumpart = (4, 5, 6, 8, 9, 10), prodpart = (1, 2, 3 , 7))
┌ Info: found:
└   buildgroups(n, partition) = (result = 42, sumpart = (1, 2, 3, 4, 5, 8, 9, 10), prodpart = (6 , 7))
┌ Info: found:
└   buildgroups(n, partition) = (result = 40, sumpart = (2, 3, 5, 6, 7, 8, 9), prodpart = (1, 4, 10))
```
