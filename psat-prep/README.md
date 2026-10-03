# PSAT Prep

A study website for the PSAT/NMSQT and PSAT 10. Practice questions from the College Board question bank, read the explanation for each one, and see which skills to work on next.

It's plain HTML, CSS, and JavaScript. There's nothing to install and no server to run.

## Start practicing

1. Download this folder (`psat-prep`).
2. Open `index.html` in Chrome, Edge, Firefox, or Safari.

All 3,629 questions from College Board's PSAT/NMSQT & PSAT 10 question bank are already included (1,844 Reading and Writing, 1,785 Math), downloaded October 3, 2026.

## Refresh the questions

College Board adds questions to the bank over time. The script `scripts/fetch-questions.mjs` downloads every question in the [SAT Suite Question Bank](https://satsuitequestionbank.collegeboard.org/) for the PSAT/NMSQT & PSAT 10, with the answer and the full explanation, and saves them into `data/`.

1. Install [Node.js](https://nodejs.org) 18 or newer.
2. In a terminal:
   ```
   cd psat-prep
   node scripts/fetch-questions.mjs
   ```
3. Reload `index.html`.

It takes a few minutes. Downloads are cached in `.cache/`, so if it stops partway, run it again and it continues where it left off. Other options:

| Command | What it does |
|---|---|
| `node scripts/fetch-questions.mjs --exam psat89` | PSAT 8/9 questions instead |
| `node scripts/fetch-questions.mjs --exam sat` | SAT questions instead |
| `node scripts/fetch-questions.mjs --fresh` | Ignore the cache and download everything again |
| `node scripts/fetch-questions.mjs --no-images` | Link to images instead of embedding them |

If the download fails on a school network, College Board's site may be blocked there. Try a home network.

## What's on the site

- **Dashboard**: accuracy overall and per section, a ranked "work on these next" list, a skill map of every PSAT skill, accuracy by difficulty, pacing against test time, and a 14-day activity chart.
- **Practice**: *Smart practice* builds a set from your weakest skills (or a diagnostic if you're new). *Build your own set* lets you pick skills, difficulty, new or missed questions, explanations after each question or at the end, and an optional test-pace timer.
- **Question bank**: search and filter every question by section, domain, skill, difficulty, and your history.
- **Review**: questions you missed or marked, your answer history, and export, import, or reset of your progress.

The practice screen works like Bluebook: a split passage pane for Reading and Writing, a built-in Desmos graphing calculator beside every Math question, a math reference sheet, answer cross-out, mark for review, and a timer you can hide. The calculator keeps your graphs from one question to the next. Keyboard: <kbd>A</kbd>–<kbd>D</kbd> to choose, <kbd>Enter</kbd> to check and go to the next question.

The calculator is Desmos's own code, loaded from the jsDelivr CDN (npm package `desmos@1.5.4`) and pinned by hash, so it needs an internet connection the first time you open it.

## How the analytics decide what you need to work on

- **Mastery** for each skill is your accuracy with recent answers weighted more (each older answer counts 15% less), pulled slightly toward 50% so two or three answers can't swing it to 0% or 100%.
- **Levels**: *Needs work* is under 60%, *Getting there* is 60–79%, *Strong* is 80% or higher. A skill needs 3 answers before it gets a level.
- **Priority** ranks skills by `(1 − mastery) × how much of the test the skill's domain covers`. A weak skill in Algebra (about 35% of Math) ranks above an equally weak skill in Geometry and Trigonometry (about 12.5%).
- **Smart practice** gives most questions to your top three priority skills, adds one skill you haven't tried, picks easier questions where your mastery is low and harder ones where it's high, and shows unseen questions before ones you've already done.

## Where your progress is saved

Progress is saved in your browser (`localStorage`), so it stays on the device and browser you use. To move it to another device, use **Review → Export progress** and **Import progress**.

## Files

| Path | What it is |
|---|---|
| `index.html`, `styles.css`, `app.js` | The website |
| `data/questions-rw-*.js`, `data/questions-math-*.js` | The College Board questions, one file per domain, written by the fetch script |
| `data/sample-questions.js` | 24 original sample questions, used only if the question files are missing |
| `scripts/fetch-questions.mjs` | Downloads the question bank |

Questions and explanations belong to College Board. This site is a personal study tool and isn't affiliated with or endorsed by College Board.
