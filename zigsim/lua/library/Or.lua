return function()
	input("a")
	input("b")
	output("c")

	Not("x")
	Not("y")
	Nand("z")

	connect("a", "x.a")
	connect("b", "y.a")
	connect("x.q", "z.a")
	connect("y.q", "z.b")
	connect("z.c", "c")
end
