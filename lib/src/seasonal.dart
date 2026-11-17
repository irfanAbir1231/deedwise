part of '../main.dart';

class SeasonalAction {
  final int deedNumber;
  final String suggestion;
  const SeasonalAction(this.deedNumber, this.suggestion);
}

class SeasonalActivity {
  final String title, category, occasion, description;
  final List<SeasonalAction> actions;
  const SeasonalActivity(
    this.title,
    this.category,
    this.occasion,
    this.description,
    this.actions,
  );
}

// Occasion-based ideas, not an official calendar or a claim of religious duties.
// Keep canonical deed IDs so planning, matching and group goals stay aligned.
const seasonalActivities = <SeasonalActivity>[
  SeasonalActivity(
    'Ramadan & Eid kindness',
    'Festivals',
    'Muslim occasions',
    'Share food, offer practical help and include neighbours in acts of care.',
    [
      SeasonalAction(14, 'Arrange a meal for someone facing food insecurity.'),
      SeasonalAction(
        16,
        'Give an affordable donation to a trusted local cause.',
      ),
      SeasonalAction(18, 'Check in on a neighbour and ask what would help.'),
    ],
  ),
  SeasonalActivity(
    'Christmas giving',
    'Festivals',
    'Christian occasions',
    'Make space for generosity, companionship and practical support.',
    [
      SeasonalAction(14, 'Contribute food to a community meal.'),
      SeasonalAction(
        19,
        'Offer company or practical help to someone spending the holiday alone.',
      ),
      SeasonalAction(
        16,
        'Support a local family with a donation you can afford.',
      ),
    ],
  ),
  SeasonalActivity(
    'Easter community care',
    'Festivals',
    'Christian occasions',
    'Bring people together through kindness and a shared community effort.',
    [
      SeasonalAction(
        43,
        'Help organise an inclusive neighbourhood service activity.',
      ),
      SeasonalAction(12, 'Spend time supporting a relative who needs care.'),
    ],
  ),
  SeasonalActivity(
    'Diwali generosity',
    'Festivals',
    'Hindu, Jain, Sikh & other communities',
    'Choose thoughtful giving and safe, considerate celebrations.',
    [
      SeasonalAction(16, 'Donate to a community support project.'),
      SeasonalAction(
        18,
        'Help a neighbour prepare or tidy their shared space.',
      ),
      SeasonalAction(21, 'Welcome others with kind and respectful words.'),
    ],
  ),
  SeasonalActivity(
    'Durga Puja community support',
    'Festivals',
    'Hindu occasions',
    'Support neighbours and volunteers with welcoming, practical acts.',
    [
      SeasonalAction(
        19,
        'Offer practical assistance to an older visitor or neighbour.',
      ),
      SeasonalAction(14, 'Help provide a meal for someone in need.'),
    ],
  ),
  SeasonalActivity(
    'Holi with care',
    'Festivals',
    'Hindu & cultural occasions',
    'Celebrate with respect for other people, their choices and shared spaces.',
    [
      SeasonalAction(18, 'Help neighbours care for a shared gathering space.'),
      SeasonalAction(43, 'Join a community clean-up after a celebration.'),
    ],
  ),
  SeasonalActivity(
    'Vesak / Buddha Purnima kindness',
    'Festivals',
    'Buddhist occasions',
    'Practise compassion through giving, gentle speech and service.',
    [
      SeasonalAction(14, 'Offer food through a local community initiative.'),
      SeasonalAction(
        21,
        'Offer encouragement to someone having a difficult day.',
      ),
      SeasonalAction(19, 'Volunteer to help someone with an everyday task.'),
    ],
  ),
  SeasonalActivity(
    'Hanukkah giving & connection',
    'Festivals',
    'Jewish occasions',
    'Share time, resources and companionship with people around you.',
    [
      SeasonalAction(16, 'Give to a local support fund within your means.'),
      SeasonalAction(12, 'Check in with relatives who could use support.'),
    ],
  ),
  SeasonalActivity(
    'Passover hospitality',
    'Festivals',
    'Jewish occasions',
    'Offer thoughtful support and make others feel welcome.',
    [
      SeasonalAction(
        14,
        'Help someone access a meal that meets their dietary needs.',
      ),
      SeasonalAction(
        19,
        'Assist someone with errands or preparations when invited.',
      ),
    ],
  ),
  SeasonalActivity(
    'Vaisakhi & shared service',
    'Festivals',
    'Sikh & cultural occasions',
    'Take part in community service and share resources generously.',
    [
      SeasonalAction(14, 'Volunteer with a community food service.'),
      SeasonalAction(
        43,
        'Help a local team carry out a shared service project.',
      ),
    ],
  ),
  SeasonalActivity(
    'Paryushan reflection & kindness',
    'Festivals',
    'Jain occasions',
    'Make time for considerate speech, forgiveness and practical kindness.',
    [
      SeasonalAction(
        23,
        'Forgive a minor hurt where it is safe and appropriate.',
      ),
      SeasonalAction(21, 'Speak gently during a difficult conversation.'),
    ],
  ),
  SeasonalActivity(
    'Nowruz fresh starts',
    'Culture',
    'Persian & other cultural communities',
    'Use a fresh start to reconnect and care for people around you.',
    [
      SeasonalAction(12, 'Reconnect with a relative and offer useful support.'),
      SeasonalAction(18, 'Help a neighbour with a fresh-start task.'),
    ],
  ),
  SeasonalActivity(
    'Lunar New Year connection',
    'Culture',
    'East Asian & other communities',
    'Share kindness across generations and welcome new beginnings.',
    [
      SeasonalAction(
        11,
        'Spend time helping a parent with something they need.',
      ),
      SeasonalAction(12, 'Offer practical support to relatives.'),
    ],
  ),
  SeasonalActivity(
    'Pohela Boishakh together',
    'Culture',
    'Bengali New Year',
    'Welcome the season through inclusion, neighbourly care and shared good.',
    [
      SeasonalAction(18, 'Check on neighbours during a local celebration.'),
      SeasonalAction(43, 'Help organise an accessible community activity.'),
    ],
  ),
  SeasonalActivity(
    'New Year, shared intentions',
    'Culture',
    'New beginnings',
    'Turn a resolution into one small, achievable act of good.',
    [
      SeasonalAction(27, 'Keep a promise you made to someone.'),
      SeasonalAction(42, 'Learn a useful skill you can share with others.'),
    ],
  ),
  SeasonalActivity(
    'Harvest & gratitude',
    'Culture',
    'Harvest celebrations',
    'Share what you can and recognise the people who support your community.',
    [
      SeasonalAction(
        14,
        'Share surplus food safely with someone who needs it.',
      ),
      SeasonalAction(7, 'Express gratitude for help you received.'),
    ],
  ),
  SeasonalActivity(
    'Winter warmth',
    'Care',
    'Cold-weather support',
    'Help people access warmth, food and companionship.',
    [
      SeasonalAction(
        20,
        'Share useful winter supplies through a local collection.',
      ),
      SeasonalAction(
        15,
        'Help someone without stable shelter access local support.',
      ),
      SeasonalAction(14, 'Contribute a meal to a community food service.'),
    ],
  ),
  SeasonalActivity(
    'Summer neighbour check-ins',
    'Care',
    'Hot-weather support',
    'Offer everyday assistance and share resources with people who need them.',
    [
      SeasonalAction(18, 'Check whether a neighbour needs help with errands.'),
      SeasonalAction(
        20,
        'Contribute drinking-water supplies to a community initiative.',
      ),
    ],
  ),
  SeasonalActivity(
    'Monsoon & disaster support',
    'Care',
    'Weather-related community needs',
    'Support locally coordinated relief and people affected by displacement.',
    [
      SeasonalAction(
        17,
        'Help a displaced family through an established relief effort.',
      ),
      SeasonalAction(20, 'Donate requested supplies to a local collection.'),
      SeasonalAction(
        43,
        'Assist with a task assigned by a community relief team.',
      ),
    ],
  ),
  SeasonalActivity(
    'Community wellbeing',
    'Care',
    'Health & companionship',
    'Offer company and practical support while respecting privacy and consent.',
    [
      SeasonalAction(19, 'Help someone with errands or an everyday care task.'),
      SeasonalAction(21, 'Listen kindly and offer encouragement.'),
    ],
  ),
  SeasonalActivity(
    'Earth & environment action',
    'Environment',
    'Environmental campaigns',
    'Care for shared spaces through a practical community effort.',
    [
      SeasonalAction(
        43,
        'Join a locally organised litter collection or planting project.',
      ),
      SeasonalAction(
        20,
        'Share reusable tools or resources for a community project.',
      ),
    ],
  ),
  SeasonalActivity(
    'Seasonal neighbourhood clean-up',
    'Environment',
    'Any season',
    'Work together to make common spaces more welcoming.',
    [
      SeasonalAction(43, 'Organise a small clean-up with neighbours.'),
      SeasonalAction(18, 'Help a neighbour look after a shared area.'),
    ],
  ),
  SeasonalActivity(
    'Back-to-school support',
    'Learning',
    'School & study seasons',
    'Help learners access useful materials, time and encouragement.',
    [
      SeasonalAction(
        20,
        'Share books or school supplies through a community collection.',
      ),
      SeasonalAction(42, 'Learn something useful in a shared study session.'),
      SeasonalAction(19, 'Help a learner with a task they find difficult.'),
    ],
  ),
  SeasonalActivity(
    'Volunteer & community week',
    'Learning',
    'Service campaigns',
    'Find a manageable role in a cause your community cares about.',
    [
      SeasonalAction(43, 'Join a community volunteer project.'),
      SeasonalAction(
        19,
        'Offer a useful skill to someone who needs assistance.',
      ),
    ],
  ),
];

class SeasonalPage extends StatefulWidget {
  const SeasonalPage({super.key});
  @override
  State<SeasonalPage> createState() => _SeasonalPageState();
}

class _SeasonalPageState extends State<SeasonalPage> {
  String category = 'All', query = '';
  @override
  Widget build(BuildContext context) {
    final results = seasonalActivities
        .where(
          (a) =>
              (category == 'All' || category == a.category) &&
              '${a.title} ${a.occasion} ${a.description} ${a.actions.map((s) => s.suggestion).join(' ')}'
                  .toLowerCase()
                  .contains(query.trim().toLowerCase()),
        )
        .toList();
    return DetailPage(
      title: 'Seasonal activities',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good in every season.', style: editorial(34)),
          const SizedBox(height: 12),
          const Text(
            'Discover acts of care around religious and cultural occasions, changing seasons and community causes. Choose what matters to you.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search occasions or activities',
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in [
                'All',
                'Festivals',
                'Culture',
                'Care',
                'Environment',
                'Learning',
              ])
                ChoiceChip(
                  label: Text(c),
                  selected: category == c,
                  onSelected: (_) => setState(() => category = c),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const NoteBox(
            'Ideas for everyone, with participation always optional. Set dates that suit your local occasion; festival dates vary by year and location.',
            icon: Icons.event_outlined,
          ),
          Section('${results.length} activities to explore'),
          if (results.isEmpty)
            const EmptyState(
              'No activities found',
              'Try a different search or category, or create your own seasonal goal.',
            ),
          for (final activity in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Surface(
                onTap: () => openPage(context, SeasonalDetailPage(activity)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tag(activity.category, icon: Icons.event_outlined),
                    const SizedBox(height: 12),
                    Text(activity.title, style: editorial(23)),
                    const SizedBox(height: 5),
                    Text(
                      activity.occasion,
                      style: const TextStyle(color: green, fontSize: 12),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      activity.description,
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Explore activities',
                            style: TextStyle(
                              color: green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward, size: 18, color: green),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => openPage(context, const GroupEditor()),
            icon: const Icon(Icons.add),
            label: const Text('Create your own seasonal goal'),
          ),
        ],
      ),
    );
  }
}

class SeasonalDetailPage extends StatelessWidget {
  final SeasonalActivity activity;
  const SeasonalDetailPage(this.activity, {super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Seasonal activities',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tag(activity.category),
        const SizedBox(height: 18),
        Text(activity.title, style: editorial(34)),
        const SizedBox(height: 10),
        Text(activity.occasion, style: const TextStyle(color: green)),
        const SizedBox(height: 14),
        Text(activity.description),
        const Section('Ways to take part'),
        for (final action in activity.actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.suggestion,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    catalogDeed(action.deedNumber).title,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => openPage(
                      context,
                      PlanEditor(template: catalogDeed(action.deedNumber)),
                    ),
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: const Text('Plan this deed'),
                  ),
                ],
              ),
            ),
          ),
        const NoteBox(
          'Choose a date in your planner, or create a group goal with your own dates, progress fields and targets. Activities do not award points until a completed deed is accepted.',
          icon: Icons.event_outlined,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () =>
              openPage(context, GroupEditor(seasonalActivity: activity)),
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Create a seasonal group goal'),
        ),
      ],
    ),
  );
}
