return function()
	input("a")
	output("q")
	Nand("x")
	connect("a", "x.a")
	connect("a", "x.b")
	connect("x.c", "q")
end
