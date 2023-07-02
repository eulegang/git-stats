
# Goal

define a dsl for iterating over a projects history finding stats and throw them into a csv

# Basics

## Comment

`#` is a comment.
This makes using a shebang natural.

This language is not really meant to look like shell, 
even though it may uses it heavily.

## Binding

`xyz = ...` binds the varibles for use else where in the program.
bindings are lazy and cached.

## Strings

`"hello world"` produces a string

`"hello ${subject}"` produces an interpolated string

## Shell
the use of backticks denotes a small shell program.
the default shell of the user will be used.

```
`ls`
```
 would execute the ls program

triple backticks denote a block program (single tick must end of the same line)
triple backticks may take a shebang which will override the shell interpreter

shell invocations may be string interpolated

## Piping

piping feeds the output of one command to another

```
`ls` | `grep xyz`
```

## Function

```
func param = ...
```

defines a function that takes a parameter

## Statements

### export

yields variables to the csv

```
export xyz
```
yields the variable xyz to the column xyz

```
export sys as xyz
```
yields the variable sys to the column xyz
