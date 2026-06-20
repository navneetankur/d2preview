# d2preview.vim

A Vim/Neovim plugin to preview [d2](https://d2lang.com) blocks in markdown files.

`:D2Preview` — Preview the d2 block under the cursor, or the visually selected lines, in a side split. Re-renders on save.

In case of selection:
+ the markers are not needed.
+ Re-render only happens if you save while cursor in inside the selection, initialy set by command.

D2 blocks are of type
~~~markdown
```d2
a -> b
b -> c
```
~~~
In case of block (that is command is called without a selection)
+ The ```` ```d2 ```` start and ```` ``` ```` end is needed.
+ no other block style is implemented.

`:D2PreviewFile` — Preview all d2 blocks in the file concatenated together. Re-renders on save.
Re-render will only happens if cursor is currently in a d2 block.
