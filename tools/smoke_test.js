ObjC.import("Foundation");

const root = ObjC.unwrap($.NSFileManager.defaultManager.currentDirectoryPath);

function readText(path) {
  const text = $.NSString.stringWithContentsOfFileEncodingError(
    path,
    $.NSUTF8StringEncoding,
    null,
  );
  if (!text) {
    throw new Error(`読み込みに失敗しました: ${path}`);
  }
  return ObjC.unwrap(text);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function createFakeElement() {
  return {
    classList: {
      add() {},
      remove() {},
      toggle() {},
    },
    style: {
      setProperty() {},
    },
    addEventListener() {},
    setAttribute() {},
    focus() {},
    pause() {},
    play() {
      return { catch() {} };
    },
    hidden: false,
    disabled: false,
    value: "",
    textContent: "",
    currentTime: 0,
    offsetWidth: 0,
  };
}

const fakeElements = {};
globalThis.window = globalThis;
globalThis.document = {
  querySelector(selector) {
    if (!fakeElements[selector]) {
      fakeElements[selector] = createFakeElement();
    }
    return fakeElements[selector];
  },
};
globalThis.Image = function Image() {};

const gamePath = `${root}/game.js`;
let gameSource = readText(gamePath);
new Function(gameSource);

gameSource = gameSource
  .replace("  const state = {", "  const state = globalThis.__testState = {")
  .replace(
    "  function randomImageNumber() {",
    "  globalThis.__testRandomImageNumber = function randomImageNumber() {",
  );
new Function(gameSource)();

const visualKeys = ["01", "02", "03", "04", "05", "06", "07", "08"];
const originalRandom = Math.random;

for (let currentImage = 1; currentImage <= visualKeys.length; currentImage += 1) {
  globalThis.__testState.currentImage = currentImage;
  const currentVisualKey = visualKeys[currentImage - 1];

  for (let sample = 0; sample < 100; sample += 1) {
    Math.random = () => (sample + 0.25) / 100;
    const nextImage = globalThis.__testRandomImageNumber();
    assert(nextImage >= 1 && nextImage <= 8, `画像番号が範囲外です: ${nextImage}`);
    assert(
      visualKeys[nextImage - 1] !== currentVisualKey,
      `同じ見た目が連続します: ${currentImage} -> ${nextImage}`,
    );
  }
}

Math.random = originalRandom;

const indexSource = readText(`${root}/index.html`);
assert(!indexSource.includes("title-sky"), "タイトル画面に画像装飾が残っています");
assert(indexSource.includes("assets/ending-theme.mp3"), "エンディング曲がHTMLに登録されていません");
assert(
  indexSource.includes("製作者：空希 香蕉（そらき ばなな）"),
  "エンディング画面に製作者表記がありません",
);
assert(
  gameSource.includes("endingAudio.duration") && gameSource.includes("startEndingCreditScroll"),
  "エンディング曲の長さに同期した製作者表記のスクロールがありません",
);
assert(gameSource.includes("playSceneChangeEffect"), "画面切り替え効果音が登録されていません");
assert(gameSource.includes("playBgmFor"), "画像連動BGMが登録されていません");
assert(gameSource.includes("stopBgm"), "エンディング前のBGM停止が登録されていません");
assert(
  gameSource.includes("stopBgm(CONFESSION_BGM_FADE_SECONDS)"),
  "告白場面でBGMが停止しません",
);

for (let bgmIndex = 1; bgmIndex <= 8; bgmIndex += 1) {
  const bgmPath = `${root}/assets/bgm/heroine-0${bgmIndex}.m4a`;
  assert(
    $.NSFileManager.defaultManager.fileExistsAtPath(bgmPath),
    `BGMファイルがありません: ${bgmPath}`,
  );
  const attributes = $.NSFileManager.defaultManager.attributesOfItemAtPathError(bgmPath, null);
  const fileSize = Number(ObjC.unwrap(attributes.objectForKey("NSFileSize")));
  assert(fileSize > 400000, `BGMファイルが小さすぎます: ${bgmPath}`);
}

const endingThemePath = `${root}/assets/ending-theme.mp3`;
assert(
  $.NSFileManager.defaultManager.fileExistsAtPath(endingThemePath),
  "エンディング曲のファイルがありません",
);

"smoke test: ok / no repeated visuals / 8 bgm cues / ending audio ready";
