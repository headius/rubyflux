class Hello
  def initialize

  end

  def hello_world
    puts 1 + 1
    puts "Hello, world"
  end

  def fib(a)
    if (a < 2)
      a
    else
      fib(a - 1) + fib(a - 2)
    end
  end
end