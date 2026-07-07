const CASUAL_TO_POLITE = [
  [/아야만 해$/, "아야만 합니다", "아야만 해요"],
  [/어야만 해$/, "어야만 합니다", "어야만 해요"],
  [/아야 해$/, "아야 합니다", "아야 해요"],
  [/어야 해$/, "어야 합니다", "어야 해요"],
  [/해야 해$/, "해야 합니다", "해야 해요"],
  [/아도 돼$/, "아도 됩니다", "아도 돼요"],
  [/어도 돼$/, "어도 됩니다", "어도 돼요"],
  [/해도 돼$/, "해도 됩니다", "해도 돼요"],
  [/면 돼$/, "면 됩니다", "면 돼요"],
  [/으면 돼$/, "으면 됩니다", "으면 돼요"],
  [/을 수 있어$/, "을 수 있습니다", "을 수 있어요"],
  [/을 수 없어$/, "을 수 없습니다", "을 수 없어요"],
  [/것 같아$/, "것 같습니다", "것 같아요"],
  [/것 같은데$/, "것 같은데요", "것 같은데요"],
  [/나봐$/, "나봅니다", "나봐요"],
  [/나 봐$/, "나 봅니다", "나 봐요"],
  [/아 보여$/, "아 보입니다", "아 보여요"],
  [/어 보여$/, "어 보입니다", "어 보여요"],
  [/해 보여$/, "해 보입니다", "해 보여요"],
  [/어 있어$/, "어 있습니다", "어 있어요"],
  [/아 있어$/, "아 있습니다", "아 있어요"],
  [/을 거야$/, "을 겁니다", "을 거예요"],
  [/고 싶어$/, "고 싶습니다", "고 싶어요"],
  [/고 싶었어$/, "고 싶었습니다", "고 싶었어요"],
  [/아 줘$/, "아 주세요", "아 주세요"],
  [/어 줘$/, "어 주세요", "어 주세요"],
  [/해 줘$/, "해 주세요", "해 주세요"],
  [/아 봐$/, "아 보세요", "아 보세요"],
  [/어 봐$/, "어 보세요", "어 보세요"],
  [/해 봐$/, "해 보세요", "해 보세요"],
  [/았었어$/, "았었습니다", "았었어요"],
  [/었었어$/, "었었습니다", "었었어요"],
  [/았어$/, "았습니다", "았어요"],
  [/었어$/, "었습니다", "었어요"],
  [/했어$/, "했습니다", "했어요"],
  [/됐어$/, "됐습니다", "됐어요"],
  [/왔어$/, "왔습니다", "왔어요"],
  [/봤어$/, "봤습니다", "봤어요"],
  [/갔어$/, "갔습니다", "갔어요"],
  [/났어$/, "났습니다", "났어요"],
  [/줬어$/, "줬습니다", "줬어요"],
  [/뒀어$/, "뒀습니다", "뒀어요"],
  [/이었어$/, "이었습니다", "이었어요"],
  [/였어$/, "였습니다", "였어요"],
  [/겠어$/, "겠습니다", "겠어요"],
  [/고 있었어$/, "고 있었습니다", "고 있었어요"],
  [/고 있어$/, "고 있습니다", "고 있어요"],
  [/구나$/, "군요", "군요"],
  [/군$/, "군요", "군요"],
  [/(?<=[가-힣])네$/, "네요", "네요"],
  [/잖아$/, "잖아요", "잖아요"],
  [/거든$/, "거든요", "거든요"],
  [/는데$/, "는데요", "는데요"],
  [/인데$/, "인데요", "인데요"],
  [/지$/, "죠", "죠"],
  [/어때$/, "어때요", "어때요"],
  [/냐$/, "나요", "나요"],
  [/니$/, "나요", "나요"],
  [/같아$/, "같습니다", "같아요"],
  [/좋아$/, "좋습니다", "좋아요"],
  [/싫어$/, "싫습니다", "싫어요"],
  [/알아$/, "압니다", "알아요"],
  [/몰라$/, "모릅니다", "몰라요"],
  [/맞아$/, "맞습니다", "맞아요"],
  [/달라$/, "다릅니다", "달라요"],
  [/힘들어$/, "힘듭니다", "힘들어요"],
  [/쉬워$/, "쉽습니다", "쉬워요"],
  [/어려워$/, "어렵습니다", "어려워요"],
  [/많아$/, "많습니다", "많아요"],
  [/없어$/, "없습니다", "없어요"],
  [/있어$/, "있습니다", "있어요"],
  [/괜찮아$/, "괜찮습니다", "괜찮아요"],
  [/중요해$/, "중요합니다", "중요해요"],
  [/필요해$/, "필요합니다", "필요해요"],
  [/이야$/, "입니다", "이에요"],
  [/야$/, "입니다", "이에요"],
  [/해$/, "합니다", "해요"],
  [/자$/, "시죠", "시죠"],
  [/봐$/, "봅니다", "봐요"],
  [/와$/, "옵니다", "와요"],
  [/([^요아이])어$/, "$1어요", "$1어요"],
  [/([^요어이])아$/, "$1아요", "$1아요"],
  [/니까$/, "니까요", "니까요"],
  [/아서$/, "아서요", "아서요"],
  [/어서$/, "어서요", "어서요"],
  [/해서$/, "해서요", "해서요"],
  [/라서$/, "라서요", "라서요"],
  [/면서$/, "면서요", "면서요"],
  [/려고$/, "려고요", "려고요"],
];
const ALREADY_POLITE = ["습니다","입니다","됩니다","있습니다","없습니다","해요","이에요","예요","있어요","없어요","됐어요","했어요","이죠","거든요","네요","잖아요","군요","할게요","볼게요","인데요","는데요","겠어요","겠습니다"];
const POLITE_TO_FORMAL = [
  [/했어요$/, "했습니다"],[/됐어요$/, "됐습니다"],[/있어요$/, "있습니다"],[/없어요$/, "없습니다"],
  [/이에요$/, "입니다"],[/예요$/, "입니다"],[/해요$/, "합니다"],[/하죠$/, "합니다"],[/이죠$/, "입니다"],
  [/되죠$/, "됩니다"],[/있죠$/, "있습니다"],[/없죠$/, "없습니다"],[/았죠$/, "았습니다"],[/었죠$/, "었습니다"],
  [/겠죠$/, "겠습니다"],[/었는데요$/, "었습니다"],[/았는데요$/, "았습니다"],[/인데요$/, "입니다"],
];
function plainEndings(isFormal) {
  return [
    [/었다$/, "었습니다"],[/였다$/, "였습니다"],[/했다$/, "했습니다"],[/이다$/, "입니다"],
    [/하다$/, isFormal?"합니다":"해요"],[/되다$/, isFormal?"됩니다":"돼요"],[/있다$/, isFormal?"있습니다":"있어요"],
    [/없다$/, isFormal?"없습니다":"없어요"],[/같다$/, isFormal?"같습니다":"같아요"],[/나다$/, isFormal?"납니다":"나요"],
    [/크다$/, isFormal?"큽니다":"커요"],[/많다$/, isFormal?"많습니다":"많아요"],[/적다$/, isFormal?"적습니다":"적어요"],
    [/높다$/, isFormal?"높습니다":"높아요"],[/낮다$/, isFormal?"낮습니다":"낮아요"],[/좋다$/, isFormal?"좋습니다":"좋아요"],
    [/다르다$/, isFormal?"다릅니다":"달라요"],[/어렵다$/, isFormal?"어렵습니다":"어려워요"],[/쉽다$/, isFormal?"쉽습니다":"쉬워요"],
    [/짧다$/, isFormal?"짧습니다":"짧아요"],[/빠르다$/, isFormal?"빠릅니다":"빨라요"],
    [/ 함$/, isFormal?" 합니다":" 해요"],[/ 됨$/, isFormal?" 됩니다":" 돼요"],
    [/있음$/, isFormal?"있습니다":"있어요"],[/없음$/, isFormal?"없습니다":"없어요"],
    [/했음$/, isFormal?"했습니다":"했어요"],[/였음$/, isFormal?"였습니다":"였어요"],
  ];
}
function normalizeSingleClause(text, speechLevel) {
  let result = text.trim();
  if (!result) return text;
  let trailingPunct = "";
  const last = result.slice(-1);
  if (last==="."||last==="!"||last==="?") { trailingPunct = last; result = result.slice(0,-1); }
  const isFormal = (speechLevel==="formal"||speechLevel==="formal_mix");
  if (speechLevel==="formal") {
    for (const [pat,rep] of POLITE_TO_FORMAL) { if (pat.test(result)) return result.replace(pat,rep)+trailingPunct; }
  }
  for (const ending of ALREADY_POLITE) { if (result.endsWith(ending)) return result+trailingPunct; }
  for (const [pat,formal,polite] of CASUAL_TO_POLITE) {
    if (pat.test(result)) { const rep = isFormal?formal:polite; return result.replace(pat,rep)+trailingPunct; }
  }
  for (const [pat,rep] of plainEndings(isFormal)) { if (pat.test(result)) return result.replace(pat,rep)+trailingPunct; }
  return result+trailingPunct;
}
function normalizeKoreanEnding(text, speechLevel) {
  const trimmed = (text||"").trim();
  if (!trimmed) return text;
  if (speechLevel==="casual") return trimmed;
  const parts = trimmed.split(/([.!?]\s+)/);
  if (parts.length>1) {
    let out = "";
    for (let i=0;i<parts.length;i+=2) {
      const sentence = parts[i]; const sep = parts[i+1]||"";
      if (sentence.trim()) { out += normalizeSingleClause(sentence.trim(),speechLevel)+sep.trimEnd(); if (sep) out += " "; }
    }
    return out.trim();
  }
  return normalizeSingleClause(trimmed,speechLevel);
}
function stripCasualPronouns(text) {
  let result = text;
  const leadingSubjects = ["너는 ","너가 ","네가 ","니가 ","너도 ","네도 ","당신은 ","당신이 ","당신도 "];
  for (const subj of leadingSubjects) { if (result.startsWith(subj)) { result = result.slice(subj.length).trim(); break; } }
  const replacements = ["너에게","너한테","너를","네것을","네 것을","당신에게","당신을","당신의"];
  for (const target of replacements) { result = result.split(target).join(""); }
  while (result.includes("  ")) { result = result.split("  ").join(" "); }
  return result.trim();
}
function applyGlossary(text, glossaryMap) {
  if (!glossaryMap) return text;
  let result = text;
  const keys = Object.keys(glossaryMap).sort((a,b)=>b.length-a.length);
  for (const key of keys) { if (result.includes(key)) result = result.split(key).join(glossaryMap[key]); }
  return result;
}
function koreanPostProcess(text, speechLevel, glossaryMap) {
  if (!text) return text;
  let result = text;
  result = applyGlossary(result, glossaryMap);
  result = stripCasualPronouns(result);
  result = normalizeKoreanEnding(result, speechLevel);
  return result;
}
if (typeof module!=="undefined" && module.exports) {
  module.exports = { koreanPostProcess, normalizeKoreanEnding, stripCasualPronouns, applyGlossary };
}
