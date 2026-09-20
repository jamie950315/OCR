# OCR 50 benchmark assets

These 50 synthetic images and their expected transcriptions were generated for this application. They contain artificial examples, not captured user documents or historical model responses. They test strict transcription, punctuation, indentation, table cells, and ordered prose. Passing is not an estimate of general OCR accuracy.

`manifest.json` contains the ground truth. Its dataset ID is SHA-256 over the compact UTF-8 JSON problem array followed by each image's bytes, in problem order. Changing any content or image requires a new dataset ID.

The evaluator vendors the unmodified browser distribution of **markdown-it 14.1.0**, obtained from the official npm `markdown-it@14.1.0` package (https://www.npmjs.com/package/markdown-it/v/14.1.0). Its MIT license is in `markdown-it-LICENSE.txt`. `evaluate-markdown.js` uses that parser in an isolated JavaScriptCore context. It never executes model-generated JavaScript or loads HTML into a DOM.
