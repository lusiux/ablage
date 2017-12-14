## Elektronische Ablage für das papierlose Büro

Das Projekt wurde im Rahmen einer Session auf dem SWEC 2017 (https://swe-camp.de/) vorgestellt und anschließend hier veröffentlicht.

## General

Currently ablage has two different ways to use it:
* command line
* web based gui

The different ways unfortunately do **slightliy different** things!

## Setup

### Dependencies

Packages
* tesseract and the two data packages `deu` and `eng`
* ocrmypdf

Perl modules
* Date::Time

### Installation

Initialize your own `Classes.pm` based on `Classes.pm.tmpl`.

To enable web based gui add the directory `./html` to your webserver's configuration and allow CGI scripts to be run.

## Usage in command line mode

Store your pdfs in `./classify` or `./ocr` and run `make`.
Pdfs in ocr will be ocr-ed with ocrmypdf and then placed in `./classify`.
All pdf files in `./classify` will then be classified and a static result page is generated to `./html`.
To archive a pdf in `./store` run the command given at the end of the html file with den command line argument `-do`

## Usage in web base gui mode

In the gui mode all pdfs have to be ocr-ed and available in the `./classify` folder.
Instead of using static html pages as in command line mode the web pages are dynamically generated with the help of a CGI script.
Just open the configured URL in your browser and choose the pdf to classify.
Changing date, sender and tags with modify the command line shown at the buttom of the document.
To archive a pdf in `./store` run the command given at the end of the html file with den command line argument `-do`


## TODOs
- Installation instruction
- Usage instrustion
- Apache snippet
- Document sources of javascript code and bootstrap
- Remove local versions of bootstrap, jquery, jquery-ui and magisuggest from repository
- Screenshots
- Cleanup of result page
