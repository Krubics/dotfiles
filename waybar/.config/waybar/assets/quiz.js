"use strict";

function shuffleChoices(container) {
  const choices = Array.from(container.children);
  for (let index = choices.length - 1; index > 0; index -= 1) {
    const swapWith = Math.floor(Math.random() * (index + 1));
    [choices[index], choices[swapWith]] = [choices[swapWith], choices[index]];
  }
  choices.forEach((choice) => container.appendChild(choice));
}

function initializeQuiz(quiz) {
  const questions = Array.from(quiz.querySelectorAll("[data-question]"));
  const progress = quiz.querySelector("[data-quiz-progress]");
  const complete = quiz.querySelector("[data-quiz-complete]");
  const reset = quiz.querySelector("[data-quiz-reset]");

  function updateProgress() {
    const correct = questions.filter((question) => question.dataset.solved === "true").length;
    progress.textContent = `${correct} / ${questions.length} diagnosed`;
    complete.classList.toggle("is-visible", correct === questions.length);
  }

  function resetQuestion(question, shouldShuffle) {
    question.dataset.solved = "false";
    question.classList.remove("is-correct");
    const feedback = question.querySelector("[data-feedback]");
    feedback.textContent = "Choose the earliest gate contradicted by the evidence.";
    feedback.dataset.state = "idle";
    const choices = question.querySelector("[data-choices]");
    choices.querySelectorAll("[data-choice]").forEach((choice) => {
      choice.disabled = false;
      choice.classList.remove("is-correct", "is-wrong");
      choice.removeAttribute("aria-pressed");
    });
    if (shouldShuffle) shuffleChoices(choices);
  }

  questions.forEach((question) => {
    resetQuestion(question, true);
    question.querySelectorAll("[data-choice]").forEach((choice) => {
      choice.addEventListener("click", () => {
        if (question.dataset.solved === "true") return;
        const feedback = question.querySelector("[data-feedback]");
        question.querySelectorAll("[data-choice]").forEach((candidate) => {
          candidate.classList.remove("is-wrong");
          candidate.setAttribute("aria-pressed", String(candidate === choice));
        });

        if (choice.dataset.correct === "true") {
          question.dataset.solved = "true";
          question.classList.add("is-correct");
          choice.classList.add("is-correct");
          question.querySelectorAll("[data-choice]").forEach((candidate) => { candidate.disabled = true; });
          feedback.textContent = choice.dataset.feedback;
          feedback.dataset.state = "correct";
          updateProgress();
          return;
        }

        choice.classList.add("is-wrong");
        feedback.textContent = choice.dataset.feedback;
        feedback.dataset.state = "wrong";
      });
    });
  });

  reset.addEventListener("click", () => {
    questions.forEach((question) => resetQuestion(question, true));
    complete.classList.remove("is-visible");
    updateProgress();
    questions[0].querySelector("[data-choice]").focus();
  });

  updateProgress();
}

document.querySelectorAll("[data-quiz]").forEach(initializeQuiz);
