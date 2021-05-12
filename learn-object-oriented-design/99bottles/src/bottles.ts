import * as ut from "./ut"

export class Bottles {
  song(): string {
    return this.verses(99, 0)
  }

  verses(max: number, min: number): string {
    return ut
      .downTo(max, min)
      .map((n) => this.verse(n))
      .join("\n")
  }

  verse(n: number): string {
    switch (n) {
      case 0:
        return (
          `No more bottles of milk on the wall, ` +
          `no more bottles of milk.\n` +
          `Go to the store and buy some more, ` +
          `99 bottles of milk on the wall.\n`
        )
      case 1:
        return (
          `${n} ${this.container(n)} of milk on the wall, ` +
          `${n} ${this.container(n)} of milk.\n` +
          `Take it down and pass it around, ` +
          `no more bottles of milk on the wall.\n`
        )
      default:
        return (
          `${n} ${this.container(n)} of milk on the wall, ` +
          `${n} ${this.container(n)} of milk.\n` +
          `Take one down and pass it around, ` +
          `${n - 1} ${this.container(n - 1)} of milk on the wall.\n`
        )
    }
  }

  container(n: number): string {
    if (n === 1) {
      return "bottle"
    } else {
      return "bottles"
    }
  }
}
