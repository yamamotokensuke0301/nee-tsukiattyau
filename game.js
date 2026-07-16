(function () {
  "use strict";

  const IMAGE_COUNT = 8;
  const INTRO_LINE = "ニシシ はじめまして";
  const REPLY_LINE = "うん";
  const CONFESSION_LINE = "ねぇ 私たち付き合っちゃう？";
  const TRANSITION_MS = 190;
  const IMAGE_ASSET_VERSION = "20260716-angle1";

  const imageSources = Array.from(
    { length: IMAGE_COUNT },
    (_, index) =>
      `./assets/heroine-${String(index + 1).padStart(2, "0")}.jpg?v=${IMAGE_ASSET_VERSION}`,
  );

  const imageAltTexts = [
    "山あいの道で微笑む少女",
    "夏空の下で振り返る少女",
    "縁側に腰掛ける少女",
    "山のバス停で横顔を見せる少女",
    "夕方の水場で手を洗う少女",
    "花を手に伏し目がちに立つ少女",
    "座卓でノートを書く少女",
    "木陰から夏空を見上げる少女",
  ];

  const imageVisualKeys = ["01", "02", "03", "04", "05", "06", "07", "08"];

  const screens = {
    title: document.querySelector("#title-screen"),
    game: document.querySelector("#game-screen"),
    ending: document.querySelector("#ending-screen"),
  };

  const startButton = document.querySelector("#start-button");
  const sceneFrame = document.querySelector("#scene-frame");
  const heroineImage = document.querySelector("#heroine-image");
  const heroineDialogue = document.querySelector("#heroine-dialogue");
  const heroineLine = document.querySelector("#heroine-line");
  const playerEcho = document.querySelector("#player-echo");
  const playerLine = document.querySelector("#player-line");
  const turnCounter = document.querySelector("#turn-counter");
  const speechForm = document.querySelector("#speech-form");
  const speechInput = document.querySelector("#speech-input");
  const sendButton = document.querySelector("#send-button");
  const choicePanel = document.querySelector("#choice-panel");
  const yesButton = document.querySelector("#yes-button");
  const noButton = document.querySelector("#no-button");
  const endingAudio = document.querySelector("#ending-audio");
  const endingCredit = document.querySelector("#ending-credit");

  let effectAudioContext = null;

  const state = {
    turn: 0,
    currentImage: 1,
    mode: "title",
    transitioning: false,
  };

  function preloadImages() {
    imageSources.forEach((source) => {
      const image = new Image();
      image.src = source;
    });
  }

  function setActiveScreen(screenName) {
    Object.entries(screens).forEach(([name, screen]) => {
      const isActive = name === screenName;
      screen.classList.toggle("is-active", isActive);
      screen.setAttribute("aria-hidden", String(!isActive));
    });
  }

  function updateTurnCounter() {
    turnCounter.textContent = `ことば ${state.turn}`;
  }

  function setComposerVisible(isVisible) {
    speechForm.hidden = !isVisible;
    choicePanel.hidden = isVisible;
  }

  function setInputBusy(isBusy) {
    speechInput.disabled = isBusy;
    sendButton.disabled = isBusy;
  }

  function restartDialogueAnimation() {
    heroineDialogue.classList.remove("is-speaking");
    void heroineDialogue.offsetWidth;
    heroineDialogue.classList.add("is-speaking");
  }

  function setSceneImage(imageNumber) {
    const source = imageSources[imageNumber - 1];
    state.currentImage = imageNumber;
    heroineImage.src = source;
    heroineImage.alt = imageAltTexts[imageNumber - 1];
    sceneFrame.style.setProperty("--scene-image", `url("${source}")`);
  }

  function randomImageNumber() {
    const currentVisualKey = imageVisualKeys[state.currentImage - 1];
    const candidates = imageVisualKeys
      .map((visualKey, index) => ({ imageNumber: index + 1, visualKey }))
      .filter((candidate) => candidate.visualKey !== currentVisualKey);
    const selectedIndex = Math.floor(Math.random() * candidates.length);
    return candidates[selectedIndex].imageNumber;
  }

  function prepareEffectAudio() {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) {
      return null;
    }

    if (!effectAudioContext) {
      effectAudioContext = new AudioContextClass();
    }

    if (effectAudioContext.state === "suspended") {
      const resume = effectAudioContext.resume();
      if (resume && typeof resume.catch === "function") {
        resume.catch(() => {});
      }
    }

    return effectAudioContext;
  }

  function playSceneChangeEffect() {
    const audioContext = prepareEffectAudio();
    if (!audioContext) {
      return;
    }

    const startAt = audioContext.currentTime + 0.01;
    const oscillator = audioContext.createOscillator();
    const gain = audioContext.createGain();

    oscillator.type = "sine";
    oscillator.frequency.setValueAtTime(440, startAt);
    oscillator.frequency.exponentialRampToValueAtTime(660, startAt + 0.09);
    gain.gain.setValueAtTime(0.0001, startAt);
    gain.gain.exponentialRampToValueAtTime(0.055, startAt + 0.018);
    gain.gain.exponentialRampToValueAtTime(0.0001, startAt + 0.14);

    oscillator.connect(gain);
    gain.connect(audioContext.destination);
    oscillator.start(startAt);
    oscillator.stop(startAt + 0.15);
  }

  const BGM_ASSET_VERSION = "20260716-acoustic1";
  const BGM_FADE_SECONDS = 1.35;
  const BGM_LEVEL = 0.54;
  const CONFESSION_BGM_FADE_SECONDS = TRANSITION_MS / 1000;

  const bgmSources = Array.from(
    { length: IMAGE_COUNT },
    (_, index) =>
      `./assets/bgm/heroine-${String(index + 1).padStart(2, "0")}.m4a?v=${BGM_ASSET_VERSION}`,
  );

  const bgmBufferPromises = new Array(IMAGE_COUNT).fill(null);
  let bgmCurrent = null;
  let bgmRequestId = 0;

  function ensureBgmBuffer(imageNumber) {
    const index = imageNumber - 1;
    if (!bgmBufferPromises[index]) {
      const audioContext = prepareEffectAudio();
      if (!audioContext) {
        return Promise.resolve(null);
      }
      bgmBufferPromises[index] = fetch(bgmSources[index])
        .then((response) => {
          if (!response.ok) {
            throw new Error(`BGMの取得に失敗しました: ${response.status}`);
          }
          return response.arrayBuffer();
        })
        .then((data) => audioContext.decodeAudioData(data))
        .catch(() => {
          // BGMが読めない環境でも、ゲームは無音のまま続行する。
          bgmBufferPromises[index] = null;
          return null;
        });
    }
    return bgmBufferPromises[index];
  }

  function preloadBgm() {
    for (let imageNumber = 1; imageNumber <= IMAGE_COUNT; imageNumber += 1) {
      ensureBgmBuffer(imageNumber);
    }
  }

  function fadeOutCurrentBgm(audioContext, seconds) {
    if (!bgmCurrent) {
      return;
    }
    const { source, gain } = bgmCurrent;
    const now = audioContext.currentTime;
    gain.gain.cancelScheduledValues(now);
    gain.gain.setValueAtTime(Math.max(gain.gain.value, 0.0001), now);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + seconds);
    source.stop(now + seconds + 0.05);
    bgmCurrent = null;
  }

  function stopBgm(seconds) {
    bgmRequestId += 1;
    if (!effectAudioContext || !bgmCurrent) {
      return;
    }
    fadeOutCurrentBgm(effectAudioContext, seconds);
  }

  async function playBgmFor(imageNumber) {
    const audioContext = prepareEffectAudio();
    if (!audioContext) {
      return;
    }
    if (bgmCurrent && bgmCurrent.imageNumber === imageNumber) {
      return;
    }
    bgmRequestId += 1;
    const requestId = bgmRequestId;
    const buffer = await ensureBgmBuffer(imageNumber);
    if (!buffer || requestId !== bgmRequestId) {
      return;
    }
    const now = audioContext.currentTime;
    fadeOutCurrentBgm(audioContext, BGM_FADE_SECONDS);
    const source = audioContext.createBufferSource();
    source.buffer = buffer;
    source.loop = true;
    const gain = audioContext.createGain();
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(BGM_LEVEL, now + BGM_FADE_SECONDS);
    source.connect(gain);
    gain.connect(audioContext.destination);
    source.start(now);
    bgmCurrent = { imageNumber, source, gain };
  }

  function stopEndingTheme() {
    endingAudio.pause();
    endingAudio.currentTime = 0;
    endingCredit.classList.remove("is-scrolling");
  }

  function updateEndingCreditDuration() {
    if (Number.isFinite(endingAudio.duration) && endingAudio.duration > 0) {
      endingCredit.style.setProperty("--ending-credit-duration", `${endingAudio.duration}s`);
    }
  }

  function startEndingCreditScroll() {
    updateEndingCreditDuration();
    endingCredit.classList.remove("is-scrolling");
    void endingCredit.offsetWidth;
    endingCredit.classList.add("is-scrolling");
  }

  function playEndingTheme() {
    stopEndingTheme();
    startEndingCreditScroll();
    const playback = endingAudio.play();
    if (playback && typeof playback.catch === "function") {
      playback.catch(() => {
        // 音声再生を拒否するブラウザでも、エンディング画面はそのまま表示する。
      });
    }
  }

  function wait(milliseconds) {
    return new Promise((resolve) => window.setTimeout(resolve, milliseconds));
  }

  async function transitionToRandomScene() {
    if (state.transitioning) {
      return;
    }

    state.transitioning = true;
    setInputBusy(true);
    sceneFrame.classList.add("is-changing");
    const nextImage = randomImageNumber();
    if (nextImage === 1) {
      stopBgm(CONFESSION_BGM_FADE_SECONDS);
    }
    await wait(TRANSITION_MS);

    playSceneChangeEffect();
    setSceneImage(nextImage);

    if (nextImage === 1) {
      state.mode = "question";
      heroineLine.textContent = CONFESSION_LINE;
      setComposerVisible(false);
    } else {
      playBgmFor(nextImage);
      state.mode = "conversation";
      heroineLine.textContent = REPLY_LINE;
      setComposerVisible(true);
    }

    restartDialogueAnimation();
    sceneFrame.classList.remove("is-changing");
    await wait(TRANSITION_MS);
    state.transitioning = false;
    setInputBusy(false);

    if (state.mode === "conversation") {
      speechInput.focus({ preventScroll: true });
    } else {
      yesButton.focus({ preventScroll: true });
    }
  }

  function resetGame() {
    stopEndingTheme();
    state.turn = 0;
    state.currentImage = 1;
    state.mode = "conversation";
    state.transitioning = false;
    setSceneImage(1);
    heroineLine.textContent = INTRO_LINE;
    playerLine.textContent = "";
    playerEcho.hidden = true;
    speechInput.value = "";
    speechForm.classList.remove("has-error");
    setComposerVisible(true);
    setInputBusy(false);
    updateTurnCounter();
    restartDialogueAnimation();
  }

  function startGame() {
    playSceneChangeEffect();
    resetGame();
    preloadBgm();
    playBgmFor(1);
    setActiveScreen("game");
    window.setTimeout(() => speechInput.focus({ preventScroll: true }), 520);
  }

  async function handleSpeechSubmit(event) {
    event.preventDefault();
    if (state.transitioning || state.mode !== "conversation") {
      return;
    }

    const speech = speechInput.value.trim();
    if (!speech) {
      speechForm.classList.remove("has-error");
      void speechForm.offsetWidth;
      speechForm.classList.add("has-error");
      speechInput.focus();
      return;
    }

    speechForm.classList.remove("has-error");
    prepareEffectAudio();
    playerLine.textContent = speech;
    playerEcho.hidden = false;
    speechInput.value = "";
    state.turn += 1;
    updateTurnCounter();
    await transitionToRandomScene();
  }

  function showEnding() {
    if (state.transitioning || state.mode !== "question") {
      return;
    }
    playSceneChangeEffect();
    stopBgm(0.8);
    state.mode = "ending";
    setActiveScreen("ending");
    playEndingTheme();
  }

  async function declineConfession() {
    if (state.transitioning || state.mode !== "question") {
      return;
    }
    prepareEffectAudio();
    state.mode = "conversation";
    setComposerVisible(true);
    await transitionToRandomScene();
  }

  startButton.addEventListener("click", startGame);
  speechForm.addEventListener("submit", handleSpeechSubmit);
  yesButton.addEventListener("click", showEnding);
  noButton.addEventListener("click", declineConfession);

  heroineImage.addEventListener("load", () => {
    sceneFrame.classList.remove("is-changing");
  });

  endingAudio.addEventListener("loadedmetadata", updateEndingCreditDuration);

  preloadImages();
})();
