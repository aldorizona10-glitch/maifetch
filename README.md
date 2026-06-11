# maifetch
a really lazy fetch tool for [maitea](https://maitea.app) written in Emacs Lisp.
It can run directly inside Emacs with `M-x maifetch`, or from a shell in Emacs
batch mode.

![image](https://github.com/user-attachments/assets/96cd7018-8a00-4785-a1a8-9fe503263662)

## configuration
| variable     | description                                        | default                                    | environment variable | cli argument          |
|--------------|----------------------------------------------------|--------------------------------------------|----------------------|-----------------------|
| access token | token for your MaiTea account (REQUIRED)           | `N/A`                                      | `MAITEA_TOKEN`       | `--access-token` `--token` `-a` `-t` |
| logo size    | size of the ASCII logo (zero or negative disables) | `20`                                       | `MAITEA_LOGO_SIZE`   | `--logo-size` `-l`    |
| score count  | amount of scores to display (max 12)               | `4`                                        | `MAITEA_SCORE_COUNT`  | `--score-count` `-s`  |
| config file  | json file to store config variables                | [refer to below](#default-config-location) | `MAITEA_CONFIG_FILE` | `--config-file` `-c`  |

`MAIFETCH_*` environment variables are also accepted as compatibility aliases.
Configuration precedence is CLI > environment variables > config file > defaults.

### Default config location
The Emacs Lisp rewrite uses:

```text
~/.emacs.d/maifetch.json
```

You can point to another file with `MAITEA_CONFIG_FILE` or `--config-file`.

Example config:

```json
{
  "accessToken": "YOUR_TOKEN",
  "scoreCount": 4,
  "logoSize": 0
}
```

## how to run
1. clone the project with `git clone https://github.com/HutchyBen/maifetch`
2. open Emacs in the project directory
3. load the package with `M-x load-file RET maifetch.el RET`
4. run `M-x maifetch`

Shell usage:

```bash
emacs --batch -l maifetch.el --funcall maifetch-batch -- --access-token YOUR_TOKEN --logo-size 0
```

Help:

```bash
emacs --batch -l maifetch.el --funcall maifetch-batch -- --help
```

## API wrapper

The rewrite exposes small functions for use from Emacs Lisp:

- `maifetch-get-profiles`
- `maifetch-get-plays`
- `maifetch-get-all-plays`
- `maifetch-get-best-scores`
- `maifetch-get-all-best-scores`
- `maifetch-page-data`
- `maifetch-page-next-url`
- `maifetch-page-prev-url`

## tests

```bash
emacs --batch -L . -l maifetch-test.el -f ert-run-tests-batch-and-exit
```


## todo
- package for MELPA-style installation if this grows beyond a single-file tool
