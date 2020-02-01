"""
WENO interpolation schemes following the procedure outlined in §2 of Shu (2009).
Combining k interpolants each of order k will produce a scheme of order 2k-1.

Shu (2009) "High Order Weighted Essentially Nonoscillatory Schemes for
    Convection Dominated Problems", SIAM Review 51(1), pp. 82–126.
    DOI: https://doi.org/10.1137/070679065
"""

const Δx = 1
x(i) = i*Δx

# Lagrange interpolants or Lagrange basis polynomials
ℓ(i, k, x′) = prod([(x′ - x(j)) // (x(i) - x(j)) for j in 0:k if j != i])

# Return array of coefficients for interpolant of order k centered around x = s + 1/2.
c_ks(k, s) = [ℓ(i, k, s + 1//2) for i in 0:k]

function print_interpolant(k, s)
    cs = csw(k, s)

    ssign(n) = n >= 0 ? "+" : "-"
    ssubscript(n) = n == 0 ? "i" : "i" * ssign(n) * string(abs(n))

    print("u(i+1//2) = ")
    for (j, c) in enumerate(cs)
        c_s = ssign(c) * " " * string(abs(c))
        ss_s = ssubscript(j-s-1)
        print(c_s * " u(" * ss_s * ") ")
    end
    print("\n")
end

function print_interpolants(k)
    for s in 0:k
        print_interpolant(k, s)
    end
end

println("WENO-5 [Compare with Shu (2009) equations (2.1)-(3.3)]:")
print_interpolants(2)

println("\nWENO-7:")
print_interpolants(4)

println("\nWENO-9:")
print_interpolants(6)
