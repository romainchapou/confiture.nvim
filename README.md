# confiture.nvim

A simple way to save and launch your project specific commands.

Note: this is a WIP, still under testing, the interface may change.


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

# a comment
variable: "value"
build_flags: "-j16"
run_command: "echo ${variable}"
```

Then start neovim in this same root folder and use `:Confiture` to launch your commands.


### `project.conf` content

You can define variables with `:` and use them in other variables using the `${var}` syntax.

Some variable names have a special meaning:

- commands/flags you can define:
    - `configure_command`: the command launched by `:Confiture configure`
    - `build_flags`: the flags to be given to `:make` that will be launched by `:Confiture build`
    - `run_command`: the command launched by `:Confiture run`
    - `clean_command`: the command launched by `:Confiture clean`
- settings:
    - `run_command_in_term`: can be `"true"` or `"false"` (don't forget the `"`). If true, the run command will be launched in a nvim terminal window. Defaults to false.
    - `makeprg`: the makeprg value to use for the call to `:make`, see `:help makeprg`. Defaults to neovim's global `makeprg`.
- convenience:
    - `src_folder`: the root folder of your project, the one containing your `project.conf` file. **Do not define this yourself**, it will be automatically defined, but you can use its value.


### `:Confiture` commands

- `:Confiture configure`
- `:Confiture build`
- `:Confiture run`
- `:Confiture clean`
- `:Confiture build_and_run`: launch the build command, and if it succeeds, launch the run command.
- `:Confiture reload`: reload your `project.conf` file. If no previous config file has been loaded, will try to source a `project.conf` file from your current working directory.


### A simple example using `make`

```conf
# my project.conf for a simple cpp project using make
run_command_in_term: "true"

# no configure command needed
build_flags: "-j16 -C ${src_folder}"
run_command: "cd ${src_folder} && ./my_exec"
clean_command: "cd ${src_folder} && make clean"
```


### A more complex example for a `cmake` project

```conf
# my project.conf for a cmake project
build_type: "Release"
build_folder: "build-${build_type}"

configure_command: "cd ${src_folder} && mkdir -p ${build_folder} && cd ${build_folder} && cmake .. -DCMAKE_BUILD_TYPE ${build_type}"
build_flags: "-j16 -C ${src_folder}/${build_folder}"
run_command: "cd ${src_folder}/${build_folder} && ./test/my_test"
clean_command: "cd ${src_folder}/${build_folder} && make clean"
```


### Some recommended mappings

```vim
nnoremap <leader>c :Confiture configure<cr>
nnoremap <leader>b :Confiture build<cr>
" double <cr> to skip the confirmation prompt
nnoremap <leader><cr> :Confiture build_and_run<cr><cr>
```


### Advanced usage note

To find out if a build succeeded, the plugin parses the quickfix list for errors (as we can't easily get the error code of the `:make` command). This relies on a regex which may not always work. You can provide your own regex (in lua format) by setting the variable `error_match_str` in your `project.conf`. Default value is `^%s*%l*%s*error: `.
