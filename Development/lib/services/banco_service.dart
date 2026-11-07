import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../model/tarefa.dart';

/// Acesso assíncrono ao SQLite e persistência das tarefas.
///
/// Por padrão, o banco é criado no diretório de bancos da plataforma. Os
/// parâmetros do construtor permitem usar um arquivo e uma fábrica isolados em
/// testes sem alterar o comportamento usado pelo aplicativo Android.
class BancoService {
  factory BancoService({
    String nomeBanco = 'flow_task.db',
    String? caminhoBanco,
    DatabaseFactory? fabricaBanco,
  }) {
    return BancoService._(
      nomeBanco,
      caminhoBanco,
      fabricaBanco ?? databaseFactory,
    );
  }

  BancoService._(this._nomeBanco, this._caminhoBanco, this._fabricaBanco);

  static const _versaoBanco = 1;
  static const _tabelaTarefas = 'tarefas';

  final String _nomeBanco;
  final String? _caminhoBanco;
  final DatabaseFactory _fabricaBanco;

  Future<Database>? _aberturaBanco;

  /// Insere [tarefa] com um identificador novo gerado pelo SQLite.
  Future<int> inserirTarefa(Tarefa tarefa) async {
    final banco = await _obterBanco();
    return banco.insert(_tabelaTarefas, _tarefaParaMapa(tarefa));
  }

  /// Consulta uma tarefa pelo [identificador], ou retorna `null` se não existir.
  Future<Tarefa?> consultarTarefaPorId(int identificador) async {
    final banco = await _obterBanco();
    final resultados = await banco.query(
      _tabelaTarefas,
      where: 'identificador = ?',
      whereArgs: [identificador],
      limit: 1,
    );

    if (resultados.isEmpty) {
      return null;
    }
    return _tarefaDoMapa(resultados.single);
  }

  /// Consulta somente as tarefas do dia civil representado por [data].
  ///
  /// Hora, minuto e fuso de [data] não participam da comparação.
  Future<List<Tarefa>> consultarTarefasPorData(DateTime data) async {
    final dataCivil = _formatarDataCivil(data);
    return _consultarTarefas(where: 'data_civil = ?', whereArgs: [dataCivil]);
  }

  /// Consulta o intervalo civil de [dataInicial] até [dataFinal], inclusive.
  ///
  /// Hora, minuto e fuso dos limites não participam da comparação. Um intervalo
  /// com a data final anterior à inicial é inválido.
  Future<List<Tarefa>> consultarTarefasPorIntervalo(
    DateTime dataInicial,
    DateTime dataFinal,
  ) async {
    final inicio = DateTime(
      dataInicial.year,
      dataInicial.month,
      dataInicial.day,
    );
    final fim = DateTime(dataFinal.year, dataFinal.month, dataFinal.day);
    if (fim.isBefore(inicio)) {
      throw ArgumentError.value(
        dataFinal,
        'dataFinal',
        'Deve ser igual ou posterior a dataInicial.',
      );
    }

    final limiteFinalExclusivo = DateTime(fim.year, fim.month, fim.day + 1);
    return _consultarTarefas(
      where: 'data_civil >= ? AND data_civil < ?',
      whereArgs: [
        _formatarDataCivil(inicio),
        _formatarDataCivil(limiteFinalExclusivo),
      ],
    );
  }

  /// Atualiza a tarefa indicada por [identificador].
  ///
  /// Retorna a quantidade de registros alterados (zero ou um). O identificador
  /// contido em [tarefa], se houver, não substitui o parâmetro explícito.
  Future<int> atualizarTarefa(int identificador, Tarefa tarefa) async {
    final banco = await _obterBanco();
    return banco.update(
      _tabelaTarefas,
      _tarefaParaMapa(tarefa),
      where: 'identificador = ?',
      whereArgs: [identificador],
    );
  }

  /// Exclui a tarefa indicada por [identificador].
  ///
  /// Retorna a quantidade de registros excluídos (zero ou um).
  Future<int> excluirTarefa(int identificador) async {
    final banco = await _obterBanco();
    return banco.delete(
      _tabelaTarefas,
      where: 'identificador = ?',
      whereArgs: [identificador],
    );
  }

  /// Fecha o banco aberto por esta instância.
  ///
  /// Uma operação posterior abre novamente o mesmo arquivo.
  Future<void> fechar() async {
    final abertura = _aberturaBanco;
    _aberturaBanco = null;
    if (abertura != null) {
      final banco = await abertura;
      await banco.close();
    }
  }

  Future<Database> _obterBanco() {
    return _aberturaBanco ??= _abrirBanco();
  }

  Future<Database> _abrirBanco() async {
    final caminho =
        _caminhoBanco ??
        path.join(await _fabricaBanco.getDatabasesPath(), _nomeBanco);

    return _fabricaBanco.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: _versaoBanco,
        onCreate: (banco, versao) async {
          await banco.execute('''
            CREATE TABLE $_tabelaTarefas (
              identificador INTEGER PRIMARY KEY AUTOINCREMENT,
              titulo TEXT NOT NULL,
              descricao TEXT,
              data_civil TEXT NOT NULL,
              horario_minutos INTEGER,
              duracao_estimada_microssegundos INTEGER,
              tempo_registrado_microssegundos INTEGER NOT NULL,
              prioridade TEXT NOT NULL,
              categoria TEXT,
              situacao TEXT NOT NULL,
              CHECK (horario_minutos IS NULL OR
                     horario_minutos BETWEEN 0 AND 1439),
              CHECK (prioridade IN ('baixa', 'media', 'alta')),
              CHECK (situacao IN
                     ('pendente', 'concluida', 'atrasada', 'pausada'))
            )
          ''');
          await banco.execute('''
            CREATE INDEX indice_tarefas_data_ordem
            ON $_tabelaTarefas (
              data_civil,
              horario_minutos,
              identificador
            )
          ''');
        },
      ),
    );
  }

  Future<List<Tarefa>> _consultarTarefas({
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final banco = await _obterBanco();
    final resultados = await banco.query(
      _tabelaTarefas,
      where: where,
      whereArgs: whereArgs,
      orderBy: '''
        data_civil ASC,
        CASE WHEN horario_minutos IS NULL THEN 1 ELSE 0 END ASC,
        horario_minutos ASC,
        identificador ASC
      ''',
    );
    return resultados.map(_tarefaDoMapa).toList(growable: false);
  }

  Map<String, Object?> _tarefaParaMapa(Tarefa tarefa) {
    final horario = tarefa.horario;
    return {
      'titulo': tarefa.titulo,
      'descricao': tarefa.descricao,
      'data_civil': _formatarDataCivil(tarefa.data),
      'horario_minutos': horario == null
          ? null
          : horario.hora * Duration.minutesPerHour + horario.minuto,
      'duracao_estimada_microssegundos': tarefa.duracaoEstimada?.inMicroseconds,
      'tempo_registrado_microssegundos': tarefa.tempoRegistrado.inMicroseconds,
      'prioridade': _prioridadeParaBanco(tarefa.prioridade),
      'categoria': tarefa.categoria,
      'situacao': _statusParaBanco(tarefa.status),
    };
  }

  Tarefa _tarefaDoMapa(Map<String, Object?> mapa) {
    final horarioMinutos = mapa['horario_minutos'] as int?;
    final duracaoEstimada = mapa['duracao_estimada_microssegundos'] as int?;

    return Tarefa(
      identificador: mapa['identificador'] as int,
      titulo: mapa['titulo'] as String,
      descricao: mapa['descricao'] as String?,
      data: DateTime.parse(mapa['data_civil'] as String),
      horario: horarioMinutos == null
          ? null
          : HorarioTarefa(
              hora: horarioMinutos ~/ Duration.minutesPerHour,
              minuto: horarioMinutos % Duration.minutesPerHour,
            ),
      duracaoEstimada: duracaoEstimada == null
          ? null
          : Duration(microseconds: duracaoEstimada),
      tempoRegistrado: Duration(
        microseconds: mapa['tempo_registrado_microssegundos'] as int,
      ),
      prioridade: _prioridadeDoBanco(mapa['prioridade'] as String),
      categoria: mapa['categoria'] as String?,
      status: _statusDoBanco(mapa['situacao'] as String),
    );
  }

  String _formatarDataCivil(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');
    return '$ano-$mes-$dia';
  }

  String _prioridadeParaBanco(PrioridadeTarefa prioridade) {
    return switch (prioridade) {
      PrioridadeTarefa.baixa => 'baixa',
      PrioridadeTarefa.media => 'media',
      PrioridadeTarefa.alta => 'alta',
    };
  }

  PrioridadeTarefa _prioridadeDoBanco(String valor) {
    return switch (valor) {
      'baixa' => PrioridadeTarefa.baixa,
      'media' => PrioridadeTarefa.media,
      'alta' => PrioridadeTarefa.alta,
      _ => throw FormatException('Prioridade desconhecida: $valor'),
    };
  }

  String _statusParaBanco(StatusTarefa status) {
    return switch (status) {
      StatusTarefa.pendente => 'pendente',
      StatusTarefa.concluida => 'concluida',
      StatusTarefa.atrasada => 'atrasada',
      StatusTarefa.pausada => 'pausada',
    };
  }

  StatusTarefa _statusDoBanco(String valor) {
    return switch (valor) {
      'pendente' => StatusTarefa.pendente,
      'concluida' => StatusTarefa.concluida,
      'atrasada' => StatusTarefa.atrasada,
      'pausada' => StatusTarefa.pausada,
      _ => throw FormatException('Situação desconhecida: $valor'),
    };
  }
}
