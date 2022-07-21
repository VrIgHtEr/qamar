input("a")
input("b")
output("q")

Or("x")
wire("a", "x.a")
wire("b", "x.b")

Not("y")
wire("x.q", "y.a")

wire("y.q", "q")
