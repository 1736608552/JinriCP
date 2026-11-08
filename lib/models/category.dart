class SeasonCategory {
  final String title;
  final String group;
  final String path;

  const SeasonCategory({
    required this.title,
    required this.group,
    required this.path,
  });

  static List<SeasonCategory> get defaultCategories => [
    // JinriCP Group
    const SeasonCategory(title: 'JinriCP 第一季', group: 'JinriCP 团播', path: '/bu/'),
    const SeasonCategory(title: 'JinriCP 第二季', group: 'JinriCP 团播', path: '/s2/'),
    const SeasonCategory(title: 'JinriCP 第三季', group: 'JinriCP 团播', path: '/s3/'),
    const SeasonCategory(title: 'JinriCP 第四季', group: 'JinriCP 团播', path: '/s4/'),
    const SeasonCategory(title: 'JinriCP 第五季', group: 'JinriCP 团播', path: '/s5/'),
    const SeasonCategory(title: 'JinriCP 第六季', group: 'JinriCP 团播', path: '/s6/'),

    // PandaClass Group
    const SeasonCategory(title: 'PandaClass 第一季', group: 'PandaClass 团播', path: '/pc/'),
    const SeasonCategory(title: 'PandaClass 第二季', group: 'PandaClass 团播', path: '/pc2/'),
    const SeasonCategory(title: 'PandaClass 第三季', group: 'PandaClass 团播', path: '/pc3/'),
    const SeasonCategory(title: 'PandaClass 第四季', group: 'PandaClass 团播', path: '/pc4/'),
    const SeasonCategory(title: 'PandaClass 第五季', group: 'PandaClass 团播', path: '/pc5/'),
    const SeasonCategory(title: 'PandaClass 第六季', group: 'PandaClass 团播', path: '/pc6/'),
    const SeasonCategory(title: 'PandaClass 第七季', group: 'PandaClass 团播', path: '/pc7/'),
  ];
}
