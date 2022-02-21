using Franklin: HTMLFunctionError, hfun_fill, @delay, pagevar

function hfun_bar(vname)
  val = Meta.parse(vname[1])
  return round(sqrt(val), digits=2)
end

function hfun_m1fill(vname)
  var = vname[1]
  return pagevar("index", var)
end

function lx_baz(com, _)
  # keep this first line
  brace_content = Franklin.content(com.braces[1]) # input string
  # do whatever you want here
  return uppercase(brace_content)
end

function hfun_timestamp_now()
    return string(Dates.now()) * "+00:00"
end

function recfind!(pattern, dir = "posts", out = Tuple{String, String, Date}[])
    list = readdir(dir, join = true)
    
    for p in list
        if isdir(p) 
            recfind!(pattern, p, out)
        elseif isfile(p)
            occursin(pattern, p) && push!(out, prep_meta_post(p))
        end
    end

    return out
end

function prep_meta_post(p)
    ps = splitext(p)[1]
    pubdate = nothing
    try
        pubdate = pagevar(ps, "published")
    catch err
    end
    isnothing(pubdate) || return @views (p, ps, Date(pubdate[1:10], dateformat"yyyy-mm-dd"))
    v = split(ps, "/")
    length(v) == 5 && return @views (p, ps, Date(join(v[2:4], "-"), dateformat"yyyy-mm-dd"))
    return (p, ps, Date(Dates.unix2datetime(stat(p).ctime)))
end

"""
    {{blogposts}}

Plug in the list of blog posts contained in the `/posts` folder.
Souce: <https://github.com/abhishalya/abhishalya.github.io>.
"""
@delay function hfun_blogposts()
    today = Dates.today()
    curyear = year(today)
    curmonth = month(today)
    curday = day(today)

    list = recfind!(r".*\.md$")
    filter!(x -> !endswith(x[1], "index.md"), list)
    sort!(list, by = x -> (x[3], x[2]), rev = true) # sort by date, for same dates sort alphabetically


    io = IOBuffer()
    println(io, """<ul class="posts-list nobull">""")
    for (i, post) in enumerate(list)
        pubdate = post[3]
        title = pagevar(post[2], "title")
        println(io, "<li>\n<span class=\"post-meta\">$(Dates.format(pubdate, dateformat"U dd, yyyy"))</span>")
        println(io, "<h3><a class=\"post-link\" href=\"/$(post[2])\">$title</a></h3>")
        println(io, "</li>")
    end
    println(io, "</ul>")
    return String(take!(io))
end

"""
    hfun_dateformat(params::Vector{String})

Converts datetime value from its current format to other. Can accept either two argumens: value and final format, or three arguments, value, final format and current format. By default it is presumed that value is given in `yyyy-mm-dd` format.
"""
function hfun_dateformat(params::AbstractVector{S}) where {S <: AbstractString}
    # check params
    if length(params) > 3 || length(params) < 2
        throw(HTMLFunctionError("{{dateformat ...}} should have two or three " *
                                "($(length(params)) given). Verify."))
    end

    value = hfun_fill([params[1]])
    from = if length(params) == 3
        map(c -> c == '+' ? ' ' : c, params[3])
    else
        "yyyy-mm-dd"
    end
    date = DateTime(value, from)

    to = map(c -> c == '+' ? ' ' : c, params[2])

    return Dates.format(date, to)
end

# Based on https://github.com/tlienart/Franklin.jl/pull/799.
function hfun_rss()
    rss = locvar(:rss)::String
    descr = fd2html(rss; internal=true, nop=true)
    Franklin.set_var!(Franklin.LOCAL_VARS, "rss_description", descr)
    return "<p>$descr</p>"
end

"""
    hfun_requiredfill(params::Vector{String})

Return the value for the field, just like `fill`, but throws an assertion error if the value is not given.
"""
function hfun_requiredfill(params::Vector{String})::String
    value = Franklin.hfun_fill(params)
    field = params[1]
    @assert(value != "", "Missing a value for the field $field")
    return value
end

"""
    lx_readhtml(com, _)

Embed a Pluto notebook via:
https://github.com/rikhuijzer/PlutoStaticHTML.jl
"""
function lx_readhtml(com, _)
    file = string(Franklin.content(com.braces[1]))::String
    dir = joinpath("posts", "notebooks")
    html_path = joinpath(dir, "$file.html")
    jl_path = joinpath(dir, "$file.jl")

    return """
        ```julia:pluto
        # hideall

        path = "$html_path"
        html = read(path, String)
        println("~~~\n\$html\n~~~\n")
        println("_To run this blog post locally, open [this notebook](/$jl_path) with Pluto.jl._")
        ```
        \\textoutput{pluto}
        """
end
