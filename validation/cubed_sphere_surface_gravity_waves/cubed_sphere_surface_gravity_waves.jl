using Statistics
using Logging
using Printf
using DataDeps
using JLD2

using Oceananigans
using Oceananigans.Units
using Oceananigans.CubedSpheres
using Oceananigans.Coriolis
using Oceananigans.Models.HydrostaticFreeSurfaceModels
using Oceananigans.TurbulenceClosures

using Oceananigans.Diagnostics: accurate_cell_advection_timescale

#####
##### filling grid halos
#####

# function fill_grid_halos!(grid)
#     for (face_number, grid_face) in enumerate(grid.faces[1:1])

#         grid_metrics = (grid_face.Δxᶜᶜᵃ, grid_face.Δxᶜᶠᵃ, grid_face.Δxᶠᶜᵃ, grid_face.Δxᶠᶠᵃ,
#                         grid_face.Δyᶜᶜᵃ, grid_face.Δyᶜᶠᵃ, grid_face.Δyᶠᶜᵃ, grid_face.Δyᶠᶠᵃ,
#                         grid_face.Azᶜᶜᵃ, grid_face.Azᶜᶠᵃ, grid_face.Azᶠᶜᵃ, grid_face.Azᶠᶠᵃ)

#         for Δ in grid_metrics
#             Δ[0, :] .= Δ[1, :]
#             Δ[end, :] .= Δ[end-1, :]
#             Δ[:, 0] .= Δ[:, 1]
#             Δ[:, end] .= Δ[:, end-1]
#         end
#     end

#     return nothing
# end

#####
##### Progress monitor
#####

mutable struct Progress
    interval_start_time :: Float64
end

function (p::Progress)(sim)
    wall_time = (time_ns() - p.interval_start_time) * 1e-9

    @info @sprintf("Time: %s, iteration: %d, max(|u⃗|): (%.2e, %.2e) m/s, extrema(η): (min=%.2e, max=%.2e), CFL: %.2e, wall time: %s",
                   prettytime(sim.model.clock.time),
                   sim.model.clock.iteration,
                   maximum(abs, sim.model.velocities.u),
                   maximum(abs, sim.model.velocities.v),
                   minimum(sim.model.free_surface.η),
                   maximum(sim.model.free_surface.η),
                   sim.parameters.cfl(sim.model),
                   prettytime(wall_time))

    p.interval_start_time = time_ns()

    return nothing
end

#####
##### Script starts here
#####

ENV["DATADEPS_ALWAYS_ACCEPT"] = "true"

Logging.global_logger(OceananigansLogger())

dd = DataDep("cubed_sphere_32_grid",
    "Conformal cubed sphere grid with 32×32 grid points on each face",
    "https://github.com/CliMA/OceananigansArtifacts.jl/raw/main/cubed_sphere_grids/cubed_sphere_32_grid.jld2",
    "b1dafe4f9142c59a2166458a2def743cd45b20a4ed3a1ae84ad3a530e1eff538" # sha256sum
)

DataDeps.register(dd)

cs32_filepath = datadep"cubed_sphere_32_grid/cubed_sphere_32_grid.jld2"

# Central (λ, φ) for each face of the cubed sphere
central_longitude = (0, 90,  0, 180, -90,   0)
central_latitude  = (0,  0, 90,   0,   0, -90)

function cubed_sphere_surface_gravity_waves(; face_number)

    H = 4kilometers
    grid = ConformalCubedSphereGrid(cs32_filepath, Nz=1, z=(-H, 0))

    # fill_grid_halos!(grid)

    ## Model setup

    model = HydrostaticFreeSurfaceModel(
              architecture = CPU(),
                      grid = grid,
        momentum_advection = VectorInvariant(),
              free_surface = ExplicitFreeSurface(gravitational_acceleration=0.1),
                  coriolis = nothing,
                   closure = nothing,
                   tracers = nothing,
                  buoyancy = nothing
    )

    ## Initial condition:
    ## Very small sea surface height perturbation so the resulting dynamics are well-described
    ## by a linear free surface.

    A  = 1e-5 * H  # Amplitude of the perturbation
    λ₀ = central_longitude[face_number]
    φ₀ = central_latitude[face_number]
    Δλ = 15  # Longitudinal width
    Δφ = 15  # Latitudinal width

    η′(λ, φ, z) = A * exp(- (λ - λ₀)^2 / Δλ^2) * exp(- (φ - φ₀)^2 / Δφ^2)

    set!(model, η=η′)

    ## Simulation setup

    Δt = 10minutes

    cfl = CFL(Δt, accurate_cell_advection_timescale)

    simulation = Simulation(model,
                        Δt = Δt,
                 stop_time = 5days,
        iteration_interval = 1,
                  progress = Progress(time_ns()),
                parameters = (; cfl)
    )

    # TODO: Implement NaNChecker for ConformalCubedSphereField
    empty!(simulation.diagnostics)

    fields_to_check = (
        u = model.velocities.u,
        v = model.velocities.v,
        η = model.free_surface.η,
        Gu = model.timestepper.Gⁿ.u,
        Gv = model.timestepper.Gⁿ.v,
        Gη = model.timestepper.Gⁿ.η
    )

    simulation.diagnostics[:state_checker] =
        StateChecker(model, fields=fields_to_check, schedule=IterationInterval(1))

    output_fields = merge(model.velocities, (η=model.free_surface.η,))

    simulation.output_writers[:fields] =
        JLD2OutputWriter(model, output_fields,
            schedule = TimeInterval(1hour),
              prefix = "cubed_sphere_surface_gravity_waves_face$face_number",
               force = true)

    run!(simulation)

    return simulation
end

# include("animate_sphere_on_map.jl")

# for face_number in 1:6
#     surface_gravity_waves_on_cubed_sphere(face_number)
#     animate_surface_gravity_waves_on_cubed_sphere(face_number)
# end
