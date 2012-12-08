public class HelloRunner {
  public static void main(String[] args) {
    new Hello().hello_world();
    for (int i = 0; i < 10; i++) {
      long start = System.currentTimeMillis();
      new Hello().fib(new RFixnum(35));
      System.out.println(System.currentTimeMillis() - start);
    }
  }
}
