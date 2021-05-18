# # Benchmark 1

#md # [![](https://mybinder.org/badge_logo.svg)](@__BINDER_ROOT_URL__/generated/Benchmark_1.ipynb)
#md # [![](https://img.shields.io/badge/show-nbviewer-579ACA.svg)](@__NBVIEWER_ROOT_URL__/generated/Benchmark_1.ipynb)

# We study the Hamiltonian of the Heisenberg model with periodic boundary conditions.

using Test #src
using CondensedMatterSOS
@spin σ[1:3]
heisenberg_hamiltonian(σ, true)

## Let's pick a solver from [this list](https://jump.dev/JuMP.jl/dev/installation/#Getting-Solvers).

using CSDP
solver = optimizer_with_attributes(
    () -> MOIU.CachingOptimizer(MOIU.UniversalFallback(MOIU.Model{Float64}()), CSDP.Optimizer()),
    MOI.Silent() => false,
)

# We can compute a lower bound `-2√2` to the ground state energy as follow:

include("symmetry.jl")
function hamiltonian_energy(N, maxdegree, solver; symmetry=true, kws...)
    @spin σ[1:N]
    function action(mono::CondensedMatterSOS.SpinMonomial, el::DirectSum)
        isempty(mono.variables) && return 1 * mono
        sign = 1
        vars = map(values(mono.variables)) do var
            rel_id = var.id - σ[1][1].id
            rel_index = var.index + 1
            @assert σ[rel_index][rel_id + 1] == var
            id = ((rel_id + el.c.id) % el.c.n) + σ[1][1].id
            index = (rel_index^el.k.p) - 1
            new_var = CondensedMatterSOS.SpinVariable(id, index)
            if el.k.k.id != 0 && el.k.k.id != index + 1
                sign *= -1
            end
            return new_var
        end
        return sign * CondensedMatterSOS.SpinMonomial(vars)
    end
    function action(term::CondensedMatterSOS.SpinTerm, el::DirectSum)
        return MP.coefficient(term) * action(MP.monomial(term), el)
    end
    function action(poly::CondensedMatterSOS.SpinPolynomial, el::DirectSum)
        return MP.polynomial([action(term, el) for term in MP.terms(poly)])
    end
    H = heisenberg_hamiltonian(σ, true)
    G = Lattice1Group(N)
    certificate = SymmetricIdeal(
        SumOfSquares.Certificate.MaxDegree(
            NonnegPolyInnerCone{SumOfSquares.COI.HermitianPositiveSemidefiniteConeTriangle}(),
            MonomialBasis,
            maxdegree,
        ),
        G,
        action,
    )
    if symmetry
        energy(H, maxdegree, solver; certificate = certificate, kws...)
    else
        energy(H, maxdegree, solver; kws...)
    end
end
bound, gram, ν = hamiltonian_energy(
    2,
    2,
    solver,
    symmetry = false,
    sparsity = NoSparsity(),
)
@test bound ≈ -6 rtol=1e-6 #src
bound

# We can see that the moment matrix uses all monomials:

@test length(ν.basis.monomials) == 7 #src
ν.basis.monomials

# Symmetry reduction

using CondensedMatterSOS

bound, gram, ν = hamiltonian_energy(
    2,
    2,
    solver,
)
@test bound ≈ -6 rtol=1e-6 #src
bound

display([M.basis.polynomials for M in ν.sub_moment_matrices])

@test length(ν.sub_moment_matrices) == 7
[M.basis.polynomials for M in ν.sub_moment_matrices]

bound, gram, ν = hamiltonian_energy(
    3,
    2,
    solver,
    symmetry = false,
)
@show bound
@test bound ≈ -4.5 rtol=1e-6 #src

bound, gram, ν = hamiltonian_energy(
    3,
    2,
    solver,
)
@show bound
@test bound ≈ -4.5 rtol=1e-6 #src
display([M.basis.polynomials for M in ν.sub_moment_matrices])

function f(N, d=2)
    bound, gram, ν = hamiltonian_energy(
        N,
        d,
        solver,
    )
    @show bound
    for M in ν.sub_moment_matrices
        display(M.basis.polynomials)
    end
end


# | id     | irep 1 | irep 2 | irep 3 | irep 4 |
# |--------|--------|--------|--------|--------|
# | degree | 2      | 3      | 1      | 3      |
# | mult 2 | 1      | 3      | 2      | 1      |
# | mult 3 | 3      | 6      | 4      | 3      |
# | mult 4 | 6      | 10     | 7      | 6      |
# | mult 5 | 10     | 15     | 11     | 10     |
# | mult 6 | 15     | 21     | 16     | 15     |
# | mult 7 | 21     | 28     | 22     | 21     |
