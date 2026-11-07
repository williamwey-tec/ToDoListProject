class PreferenciasNotificacoes {
  const PreferenciasNotificacoes({
    this.resumo = false,
    this.minutosResumo = 450,
    this.blocos = false,
    this.individuais = true,
    this.som = true,
    this.vibracao = true,
  });

  final bool resumo;
  final int minutosResumo;
  final bool blocos;
  final bool individuais;
  final bool som;
  final bool vibracao;

  PreferenciasNotificacoes copiarCom({
    bool? resumo,
    int? minutosResumo,
    bool? blocos,
    bool? individuais,
    bool? som,
    bool? vibracao,
  }) => PreferenciasNotificacoes(
    resumo: resumo ?? this.resumo,
    minutosResumo: minutosResumo ?? this.minutosResumo,
    blocos: blocos ?? this.blocos,
    individuais: individuais ?? this.individuais,
    som: som ?? this.som,
    vibracao: vibracao ?? this.vibracao,
  );

  Map<String, Object> paraMapa() => {
    'resumo': resumo,
    'minutosResumo': minutosResumo,
    'blocos': blocos,
    'individuais': individuais,
    'som': som,
    'vibracao': vibracao,
  };

  factory PreferenciasNotificacoes.doMapa(Map<String, dynamic> dados) {
    final minutos = dados['minutosResumo'];
    return PreferenciasNotificacoes(
      resumo: dados['resumo'] == true,
      minutosResumo: minutos is int && minutos >= 0 && minutos < 1440
          ? minutos
          : 450,
      blocos: dados['blocos'] == true,
      individuais: dados['individuais'] != false,
      som: dados['som'] != false,
      vibracao: dados['vibracao'] != false,
    );
  }
}
