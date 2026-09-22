class ContextPolicy {
  const ContextPolicy({
    this.trigger = .8,
    this.target = .6,
    this.recent = .5,
    this.margin = 1024,
  });
  final double trigger;
  final double target;
  final double recent;
  final int margin;
  Map<String, dynamic> toJson() => {
    'trigger': trigger,
    'target': target,
    'recent': recent,
    'margin': margin,
  };
  factory ContextPolicy.fromJson(Map<String, dynamic> json) => ContextPolicy(
    trigger: (json['trigger'] as num).toDouble(),
    target: (json['target'] as num).toDouble(),
    recent: (json['recent'] as num).toDouble(),
    margin: json['margin'] as int,
  );
}
