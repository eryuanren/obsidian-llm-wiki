---
description: Answer a question from the wiki, falling back to the cited sources
---
Answer this question, following the QUERY workflow in `.opencode/llm-wiki/schema.md`.

Question: $ARGUMENTS

1. Search `wiki/` with your own grep for the question's terms and their synonyms. Check
   `aliases:` in frontmatter too.
2. If search returns little, read `wiki/index.md`.
3. Open the most relevant pages and read them properly.
4. **Then go to the source.** If the answer turns on a figure, date, name, quotation, or
   any specific detail, open the cited source page's archived text in `processed/` and
   read the passage itself. The wiki is a map: its pages are summaries, and summaries
   drop exactly the footnote-level detail that precise questions ask about. Saying "the
   wiki doesn't cover it" without having opened the cited source is a wrong answer.
5. Answer concisely. Cite pages with `[[links]]`, and for any specific value cite the
   source and section you actually read it in.
6. If neither the wiki nor its sources cover it, say so plainly. Do not invent facts,
   dates, names, or behaviour, and keep your own reasoning visibly separate from what
   the sources say.
7. If pages or sources disagree, cite both and name the conflict.
8. Append a `query` entry to `wiki/log.md`:

   ```
   ## [YYYY-MM-DD] query | the question, briefly
   - Consulted: [[Page A]], processed/foo.md
   - Answer: one-line summary
   ```

Write nothing else to the wiki unless I ask. If the answer has lasting value, offer to
file it as a `wiki/synthesis/` page.
