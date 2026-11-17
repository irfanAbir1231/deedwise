part of '../main.dart';

const completedCardCaptions = <String>[
  'I worshipped God sincerely.',
  'I performed my regular prayers.',
  'I gave obligatory charity.',
  'I sought guidance and followed what is right.',
  'I fasted with the intention of becoming righteous.',
  'I remembered God.',
  'I expressed gratitude.',
  'I repented sincerely and worked to reform my conduct.',
  'I practised patience in hardship.',
  'I acted with sincere intentions.',
  'I treated my parents with kindness and respect.',
  'I cared for my relatives.',
  'I cared for orphans.',
  'I fed people who were hungry or in need.',
  'I helped homeless people or travellers in need.',
  'I gave voluntary charity from my wealth.',
  'I helped people displaced from their homes.',
  'I treated my neighbours well.',
  'I helped someone who needed assistance.',
  'I shared my resources for the public good.',
  'I spoke kindly to people.',
  'I helped people make peace.',
  'I forgave someone.',
  'I controlled my anger.',
  'I treated people with humility.',
  'I listened attentively and followed what was best.',
  'I fulfilled my promise.',
  'I spoke truthfully and avoided falsehood.',
  'I gave fair and honest testimony.',
  'I responded to wrongdoing with kindness.',
  'I upheld justice, even when it was difficult.',
  'I treated someone fairly despite our differences.',
  'I gave full measure and accurate weight.',
  'I earned and used my wealth lawfully.',
  'I protected the property and rights of orphans.',
  'I consulted others on a shared matter.',
  'I protected human life and refrained from unjust killing.',
  'I respected the rights and safety of my family members.',
  'I honoured my agreement.',
  'I stood firmly for what was right and opposed wrongdoing.',
  'I took an opportunity to do good.',
  'I sought beneficial knowledge and learned with humility.',
  'I encouraged cooperation in a good cause.',
  'I avoided mockery, insults and hurtful nicknames.',
  'I avoided suspicion, spying and backbiting.',
  'I avoided spreading corruption on Earth.',
  'I ate what was lawful and good and practised moderation.',
  'I helped bring about reconciliation and social harmony.',
  'I respected people’s rights and treated them fairly.',
  'I replaced wrongdoing with a righteous action.',
];

String cardCaption(DeedEntry entry) {
  // Personal free text already describes the action; never replace it with an
  // inferred claim based only on the nearest catalog prediction.
  final index = templates.indexWhere(
    (t) => t.title == entry.title && t.id.startsWith('quran-'),
  );
  return index < 0 ? entry.title : completedCardCaptions[index];
}
