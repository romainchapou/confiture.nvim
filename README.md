# confiture.nvim

A simple way to save and launch your project specific commands.


## Main motivations

- Use the same simple commands (for example `:Confiture build_and_run`), or better, a mapping, to launch build commands in all your projects.
- Have your project specific commands stored with your project files and not in your `vimrc`/`init.vim`.
- Have a `build_and_run` function to build with a call to `:make` and run a command if the build succeeds. 


## Installation

Install with your package manager of choice, for example with [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'romainchapou/confiture.nvim'
```


## Usage

First, create a `project.conf` file in your project root directory. This is where you will define your project commands (which simply are the shell commands you would use in a terminal). The file follows a simple syntax:

```conf
# my project.conf file

# declaring variables
variable: "value"

# declaring commands
@build: "make -j16"
@run:   "echo ${variable}"
```

Then start neovim in this same folder and use `:Confiture` to launch your commands.


### `project.conf` content

#### Commands

Commands are declared with a `@` and assigned a value with `:`. There names should be either `configure`, `build`, `run` or `clean`. The command "`cmd`" can then be executed from Neovim with a call to `:Confiture cmd`.

`build` is a special case as `:Confiture build` will launch the command with a call to `:make` to store the build results in the quickfix list.


#### Variables

Variables can be assigned a value with `:` and then used in other variables or in commands using the `${var}` syntax. Variables names can be anything you want, although some have a special meaning:

- `RUN_IN_TERM`: can be set to `"true"` or `"false"` (don't forget the `"`). If true, the `@run` command will be launched in a nvim terminal window. If false, a simple call to `:!` will be done. **Defaults to true**.


#### `:Confiture build_and_run`

`:Confiture build_and_run` is an additional command implicitly defined by `@build` and `@run`.

- If there is a `@build` command defined, launch the `build` command. Then if it succeeded, launch the `run` command.
- If there is no `@build` command defined, simply launch the `run` command.


### Examples

#### A super simple example for a script project

```conf
# my simple project.conf

# will be launched by either ':Confiture run' or ':Confiture build_and_run'
@run: "./main.py"
```


#### A simple example using `make`

```conf
# my project.conf for a simple cpp project using make
RUN_IN_TERM: "false" # run command will be executed with a simple call to ':!'

# no configure command needed
@build: "make -j16"
@run:   "./my_exec"
@clean: "make clean"
```


#### A more complex example for a `cmake` project

```conf
# my project.conf for a cmake project
build_type: "Release"
build_folder: "build-${build_type}"

@configure: "mkdir -p ${build_folder} && cd ${build_folder} && cmake .. -DCMAKE_BUILD_TYPE ${build_type}"
@build:     "make -j16 -C ${build_folder}"
@run:       "cd ${build_folder} && ./test/my_test"
@clean:     "cd ${build_folder} && make clean"
```


### Some recommended mappings

```vim
" Save all buffers and run a command
nnoremap <leader>c :wa<cr>:Confiture configure<cr>
nnoremap <leader>b :wa<cr>:Confiture build<cr>
" double <cr> to skip the confirmation prompt
nnoremap <leader><cr> :wa<cr>:Confiture build_and_run<cr><cr>
```
