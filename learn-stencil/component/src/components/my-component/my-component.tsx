import { Component, Prop, h } from "@stencil/core"

@Component({
  tag: "my-component",
  styleUrl: "my-component.css",
  shadow: true,
})
export class MyComponent {
  @Prop() first: string
  @Prop() middle: string
  @Prop() last: string

  render() {
    return (
      <div>
        Hi {this.first} {this.middle} {this.last}
      </div>
    )
  }
}
