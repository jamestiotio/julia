# Install dependencies needed to build the documentation.
empty!(LOAD_PATH)
push!(LOAD_PATH, @__DIR__, "@stdlib")
empty!(DEPOT_PATH)
pushfirst!(DEPOT_PATH, joinpath(@__DIR__, "deps"))
using Pkg
Pkg.instantiate()

using Documenter, DocumenterLaTeX

baremodule GenStdLib end

# Documenter Setup.

symlink_q(tgt, link) = isfile(link) || symlink(tgt, link)
cp_q(src, dest) = isfile(dest) || cp(src, dest)

# make links for stdlib package docs, this is needed until #552 in Documenter.jl is finished
const STDLIB_DOCS = []
const STDLIB_DIR = Sys.STDLIB
const EXT_STDLIB_DOCS = ["Pkg"]
cd(joinpath(@__DIR__, "src")) do
    Base.rm("stdlib"; recursive=true, force=true)
    mkdir("stdlib")
    for dir in readdir(STDLIB_DIR)
        sourcefile = joinpath(STDLIB_DIR, dir, "docs", "src")
        if dir in EXT_STDLIB_DOCS
            sourcefile = joinpath(sourcefile, "basedocs.md")
        else
            sourcefile = joinpath(sourcefile, "index.md")
        end
        if isfile(sourcefile)
            targetfile = joinpath("stdlib", dir * ".md")
            push!(STDLIB_DOCS, (stdlib = Symbol(dir), targetfile = targetfile))
            if Sys.iswindows()
                cp_q(sourcefile, targetfile)
            else
                symlink_q(sourcefile, targetfile)
            end
        end
    end
end

# Generate a suitable markdown file from NEWS.md and put it in src
str = read(joinpath(@__DIR__, "..", "NEWS.md"), String)
splitted = split(str, "<!--- generated by NEWS-update.jl: -->")
@assert length(splitted) == 2
replaced_links = replace(splitted[1], r"\[\#([0-9]*?)\]" => s"[#\g<1>](https://github.com/JuliaLang/julia/issues/\g<1>)")
write(joinpath(@__DIR__, "src", "NEWS.md"), replaced_links)

const PAGES = [
    "Home" => "index.md",
    hide("NEWS.md"),
    "Manual" => [
        "manual/getting-started.md",
        "manual/variables.md",
        "manual/integers-and-floating-point-numbers.md",
        "manual/mathematical-operations.md",
        "manual/complex-and-rational-numbers.md",
        "manual/strings.md",
        "manual/functions.md",
        "manual/control-flow.md",
        "manual/variables-and-scoping.md",
        "manual/types.md",
        "manual/methods.md",
        "manual/constructors.md",
        "manual/conversion-and-promotion.md",
        "manual/interfaces.md",
        "manual/modules.md",
        "manual/documentation.md",
        "manual/metaprogramming.md",
        "manual/arrays.md",
        "manual/missing.md",
        "manual/networking-and-streams.md",
        "manual/parallel-computing.md",
        "manual/running-external-programs.md",
        "manual/calling-c-and-fortran-code.md",
        "manual/handling-operating-system-variation.md",
        "manual/environment-variables.md",
        "manual/embedding.md",
        "manual/code-loading.md",
        "manual/profile.md",
        "manual/stacktraces.md",
        "manual/performance-tips.md",
        "manual/workflow-tips.md",
        "manual/style-guide.md",
        "manual/faq.md",
        "manual/noteworthy-differences.md",
        "manual/unicode-input.md",
    ],
    "Base" => [
        "base/base.md",
        "base/collections.md",
        "base/math.md",
        "base/numbers.md",
        "base/strings.md",
        "base/arrays.md",
        "base/parallel.md",
        "base/multi-threading.md",
        "base/constants.md",
        "base/file.md",
        "base/io-network.md",
        "base/punctuation.md",
        "base/sort.md",
        "base/iterators.md",
        "base/c.md",
        "base/libc.md",
        "base/stacktraces.md",
        "base/simd-types.md",
    ],
    "Standard Library" =>
        [stdlib.targetfile for stdlib in STDLIB_DOCS],
    "Developer Documentation" => [
        "devdocs/reflection.md",
        "Documentation of Julia's Internals" => [
            "devdocs/init.md",
            "devdocs/ast.md",
            "devdocs/types.md",
            "devdocs/object.md",
            "devdocs/eval.md",
            "devdocs/callconv.md",
            "devdocs/compiler.md",
            "devdocs/functions.md",
            "devdocs/cartesian.md",
            "devdocs/meta.md",
            "devdocs/subarrays.md",
            "devdocs/isbitsunionarrays.md",
            "devdocs/sysimg.md",
            "devdocs/llvm.md",
            "devdocs/stdio.md",
            "devdocs/boundscheck.md",
            "devdocs/locks.md",
            "devdocs/offset-arrays.md",
            "devdocs/require.md",
            "devdocs/inference.md",
            "devdocs/ssair.md",
            "devdocs/gc-sa.md",
        ],
        "Developing/debugging Julia's C code" => [
            "devdocs/backtraces.md",
            "devdocs/debuggingtips.md",
            "devdocs/valgrind.md",
            "devdocs/sanitizers.md",
        ]
    ],
]

for stdlib in STDLIB_DOCS
    @eval using $(stdlib.stdlib)
    # All standard library modules get `using $STDLIB` as their global
    DocMeta.setdocmeta!(Base.root_module(Base, stdlib.stdlib), :DocTestSetup, :(using $(stdlib.stdlib)), recursive=true)
end
# A few standard libraries need more than just the module itself in the DocTestSetup.
# This overwrites the existing ones from above though, hence the warn=false.
DocMeta.setdocmeta!(SparseArrays, :DocTestSetup, :(using SparseArrays, LinearAlgebra), recursive=true, warn=false)
DocMeta.setdocmeta!(UUIDs, :DocTestSetup, :(using UUIDs, Random), recursive=true, warn=false)
DocMeta.setdocmeta!(Pkg, :DocTestSetup, :(using Pkg, Pkg.Artifacts), recursive=true, warn=false)
DocMeta.setdocmeta!(Pkg.BinaryPlatforms, :DocTestSetup, :(using Pkg, Pkg.BinaryPlatforms), recursive=true, warn=false)

const render_pdf = "pdf" in ARGS
let r = r"buildroot=(.+)", i = findfirst(x -> occursin(r, x), ARGS)
    global const buildroot = i === nothing ? (@__DIR__) : first(match(r, ARGS[i]).captures)
end

const format = if render_pdf
    LaTeX(
        platform = "texplatform=docker" in ARGS ? "docker" : "native"
    )
else
    Documenter.HTML(
        prettyurls = ("deploy" in ARGS),
        canonical = ("deploy" in ARGS) ? "https://docs.julialang.org/en/v1/" : nothing,
        assets = ["assets/julia-manual.css", ],
        analytics = "UA-28835595-6",
    )
end

makedocs(
    build     = joinpath(buildroot, "doc", "_build", (render_pdf ? "pdf" : "html"), "en"),
    modules   = [Base, Core, [Base.root_module(Base, stdlib.stdlib) for stdlib in STDLIB_DOCS]...],
    clean     = true,
    doctest   = ("doctest=fix" in ARGS) ? (:fix) : ("doctest=only" in ARGS) ? (:only) : ("doctest=true" in ARGS) ? true : false,
    linkcheck = "linkcheck=true" in ARGS,
    linkcheck_ignore = ["https://bugs.kde.org/show_bug.cgi?id=136779"], # fails to load from nanosoldier?
    strict    = true,
    checkdocs = :none,
    format    = format,
    sitename  = "The Julia Language",
    authors   = "The Julia Project",
    pages     = PAGES,
)

# Only deploy docs from 64bit Linux to avoid committing multiple versions of the same
# docs from different workers.
if "deploy" in ARGS && Sys.ARCH === :x86_64 && Sys.KERNEL === :Linux

# Override a few environment variables to deploy to the appropriate repository,
# encode things like branch, whether it's built on a tag, etc....
env_mappings = [
    "TRAVIS_REPO_SLUG" => "JuliaLang/docs.julialang.org",
    "TRAVIS_BRANCH" => Base.GIT_VERSION_INFO.branch,
]

if Base.GIT_VERSION_INFO.tagged_commit
    push!(env_mappings, "TRAVIS_TAG" => "v$(Base.VERSION)")
end

withenv(env_mappings...) do
    deploydocs(
        repo = "github.com/JuliaLang/docs.julialang.org.git",
        target = joinpath(buildroot, "doc", "_build", "html", "en"),
        dirname = "en",
        devurl = "v1.3-dev",
        versions = ["v#.#", "v1.3-dev" => "v1.3-dev"]
    )
end
end
