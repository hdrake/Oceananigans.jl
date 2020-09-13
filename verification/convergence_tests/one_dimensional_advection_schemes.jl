using Test

using PyPlot
using LaTeXStrings

using Oceananigans.Advection

# Define a few utilities for running tests and unpacking and plotting results
include("ConvergenceTests/ConvergenceTests.jl")

using .ConvergenceTests
using .ConvergenceTests.OneDimensionalGaussianAdvectionDiffusion: run_test
using .ConvergenceTests.OneDimensionalUtils: unpack_errors, defaultcolors, removespines

""" Run advection test for all Nx in resolutions. """
function run_convergence_test(κ, U, resolutions, advection_scheme)

    # Determine save time-step
           Lx = 2.5
    stop_time = 0.25
            h = Lx / maximum(resolutions)
           Δt = min(0.1 * h / U, 0.01 * h^2 / κ)

    # Adjust time-step
    stop_iteration = round(Int, stop_time / Δt)
                Δt = stop_time / stop_iteration

    # Run the tests
    results = [run_test(Nx=Nx, Δt=Δt, advection=advection_scheme, stop_iteration=stop_iteration,
                        U=U, κ=κ, width=0.1) for Nx in resolutions]

    return results
end

#####
##### Run test
#####

# Nx = 2 .^ (6:8) # N = 64 through N = 256
# advection_schemes = (CenteredSecondOrder(), CenteredFourthOrder(), WENO5())
# results = Dict()

# for scheme in advection_schemes
#     results[typeof(scheme)] = run_convergence_test(1e-6, 3, Nx, scheme)
# end

rate_of_convergence(::CenteredSecondOrder) = 2
rate_of_convergence(::CenteredFourthOrder) = 4
rate_of_convergence(::WENO5) = 5

for (j, scheme) in enumerate(advection_schemes)
    u_L₁, v_L₁, cx_L₁, cy_L₁, u_L∞, v_L∞, cx_L∞, cy_L∞ = unpack_errors(results[typeof(scheme)])
    
    name = typeof(scheme) |> string
    roc = rate_of_convergence(scheme)

    test_rate_of_convergence(u_L₁,  Nx, expected=-roc, atol=Inf, name=name*" u_L₁")
    test_rate_of_convergence(v_L₁,  Nx, expected=-roc, atol=Inf, name=name*" v_L₁")
    test_rate_of_convergence(cx_L₁, Nx, expected=-roc, atol=Inf, name=name*" cx_L₁")
    test_rate_of_convergence(cy_L₁, Nx, expected=-roc, atol=Inf, name=name*" cy_L₁")
    test_rate_of_convergence(u_L∞,  Nx, expected=-roc, atol=Inf, name=name*" u_L∞")
    test_rate_of_convergence(v_L∞,  Nx, expected=-roc, atol=Inf, name=name*" v_L∞")
    test_rate_of_convergence(cx_L∞, Nx, expected=-roc, atol=Inf, name=name*" cx_L∞")
    test_rate_of_convergence(cy_L∞, Nx, expected=-roc, atol=Inf, name=name*" cy_L∞")

    @show u_L₁ ≈ v_L₁ ≈ cx_L₁ ≈ cy_L₁
    @show u_L∞ ≈ v_L∞ ≈ cx_L∞ ≈ cy_L∞
    # @test u_L₁ ≈ v_L₁ ≈ cx_L₁ ≈ cy_L₁
    # @test u_L∞ ≈ v_L∞ ≈ cx_L∞ ≈ cy_L∞
    
    fig, ax = subplots()

    common_kwargs = (linestyle="None", color=defaultcolors[j], mfc="None", alpha=0.8)
    loglog(Nx,  u_L₁; basex=2, marker="o", label="\$L_1\$-norm, \$u\$ $name", common_kwargs...)
    loglog(Nx,  v_L₁; basex=2, marker="2", label="\$L_1\$-norm, \$v\$ $name", common_kwargs...)
    loglog(Nx, cx_L₁; basex=2, marker="*", label="\$L_1\$-norm, \$x\$ tracer $name", common_kwargs...)
    loglog(Nx, cy_L₁; basex=2, marker="+", label="\$L_1\$-norm, \$y\$ tracer $name", common_kwargs...)

    loglog(Nx,  u_L∞; basex=2, marker="1", label="\$L_\\infty\$-norm, \$u\$ $name", common_kwargs...)
    loglog(Nx,  v_L∞; basex=2, marker="_", label="\$L_\\infty\$-norm, \$v\$ $name", common_kwargs...)
    loglog(Nx, cx_L∞; basex=2, marker="^", label="\$L_\\infty\$-norm, \$x\$ tracer $name", common_kwargs...)
    loglog(Nx, cy_L∞; basex=2, marker="s", label="\$L_\\infty\$-norm, \$y\$ tracer $name", common_kwargs...)

    label = raw"\sim N_x^{-" * "$roc" * raw"}" |> latexstring
    loglog(Nx, cx_L₁[1] .* (Nx[1] ./ Nx) .^ roc, "k-", basex=2, alpha=0.8, label=label)

    xlabel(L"N_x")
    ylabel("\$L\$-norms of \$ | c_\\mathrm{sim} - c_\\mathrm{analytical} |\$")
    removespines("top", "right")
    lgd = legend(loc="upper right", bbox_to_anchor=(1.4, 1.0), prop=Dict(:size=>6))

    filepath = joinpath(@__DIR__, "figs", "$(name)_one_dimensional_convergence.png")
    savefig(filepath, dpi=480, bbox_extra_artists=(lgd,), bbox_inches="tight")
    close(fig)
end