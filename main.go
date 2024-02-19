package main

import (
	"fmt"
	"os"
)

var version = "dev"

func main() {
	// if first argument is "version" print version
	if len(os.Args) > 1 && os.Args[1] == "--version" {
		fmt.Println(version)
		return
	}

	println("Hello, World!")
}
