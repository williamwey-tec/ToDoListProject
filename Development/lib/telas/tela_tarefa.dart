import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../control/control_tarefa.dart';
import '../model/tarefa.dart';
import '../services/notificacao_service.dart';
import '../tema/cores.dart';
import '../widgets/botao.dart';
import '../widgets/campo_texto.dart';

/// Formulário reutilizável de criação e edição de tarefas.
class TelaTarefa extends StatefulWidget {
  const TelaTarefa({
    super.key,
    required this.controleTarefa,
    this.tarefa,
    this.dataInicial,
    this.relogio = DateTime.now,
  });

  final OperacoesTarefa controleTarefa;
  final Tarefa? tarefa;
  final DateTime? dataInicial;
  final RelogioTarefa relogio;

  bool get estaEditando => tarefa != null;

  @override
  State<TelaTarefa> createState() => _TelaTarefaState();
}

class _TelaTarefaState extends State<TelaTarefa> {
  final _chaveFormulario = GlobalKey<FormState>();
  late final TextEditingController _tituloController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _dataController;
  late final TextEditingController _horarioController;
  late final TextEditingController _duracaoController;
  late final TextEditingController _categoriaController;

  late DateTime _dataSelecionada;
  TimeOfDay? _horarioSelecionado;
  late PrioridadeTarefa _prioridade;
  late RepeticaoTarefa _repeticao;
  late bool _lembreteAtivo;
  late int _antecedenciaMinutos;
  bool _salvando = false;
  String? _erroOperacao;

  @override
  void initState() {
    super.initState();
    final tarefa = widget.tarefa;
    final agora = widget.relogio();
    _dataSelecionada = tarefa?.data ?? widget.dataInicial ?? agora;
    _horarioSelecionado = tarefa?.horario == null
        ? (widget.estaEditando ? null : TimeOfDay.fromDateTime(agora))
        : TimeOfDay(
            hour: tarefa!.horario!.hora,
            minute: tarefa.horario!.minuto,
          );
    _prioridade = tarefa?.prioridade ?? PrioridadeTarefa.media;
    _repeticao = tarefa?.repeticao ?? RepeticaoTarefa.nenhuma;
    _lembreteAtivo = tarefa?.lembreteAtivo ?? false;
    _antecedenciaMinutos = tarefa?.antecedenciaLembrete.inMinutes ?? 15;

    _tituloController = TextEditingController(text: tarefa?.titulo ?? '');
    _descricaoController = TextEditingController(text: tarefa?.descricao ?? '');
    _dataController = TextEditingController(
      text: _formatarData(_dataSelecionada),
    );
    _horarioController = TextEditingController(
      text: _horarioSelecionado == null
          ? ''
          : _formatarHorario(_horarioSelecionado!),
    );
    _duracaoController = TextEditingController(
      text: tarefa?.duracaoEstimada == null
          ? (widget.estaEditando ? '' : '30')
          : tarefa!.duracaoEstimada!.inMinutes.toString(),
    );
    _categoriaController = TextEditingController(text: tarefa?.categoria ?? '');
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _dataController.dispose();
    _horarioController.dispose();
    _duracaoController.dispose();
    _categoriaController.dispose();
    super.dispose();
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  String _formatarHorario(TimeOfDay horario) {
    final hora = horario.hour.toString().padLeft(2, '0');
    final minuto = horario.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  String? _textoOpcional(TextEditingController controller) {
    final texto = controller.text.trim();
    return texto.isEmpty ? null : texto;
  }

  Future<void> _selecionarData() async {
    FocusScope.of(context).unfocus();
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Selecionar data da tarefa',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (selecionada == null || !mounted) return;

    setState(() {
      _dataSelecionada = selecionada;
      _dataController.text = _formatarData(selecionada);
    });
  }

  Future<void> _selecionarHorario() async {
    FocusScope.of(context).unfocus();
    final selecionado = await showTimePicker(
      context: context,
      initialTime:
          _horarioSelecionado ?? TimeOfDay.fromDateTime(widget.relogio()),
      helpText: 'Selecionar horário da tarefa',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (selecionado == null || !mounted) return;

    setState(() {
      _horarioSelecionado = selecionado;
      _horarioController.text = _formatarHorario(selecionado);
    });
    _chaveFormulario.currentState?.validate();
  }

  String? _validarTitulo(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Informe um título.';
    }
    return null;
  }

  String? _validarHorario(String? _) {
    return _horarioSelecionado == null ? 'Informe um horário.' : null;
  }

  String? _validarDuracao(String? valor) {
    final minutos = int.tryParse(valor?.trim() ?? '');
    if (minutos == null || minutos <= 0) {
      return 'Use minutos maiores que zero.';
    }
    return null;
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    FocusScope.of(context).unfocus();
    setState(() => _erroOperacao = null);
    if (!(_chaveFormulario.currentState?.validate() ?? false)) return;

    final controle = widget.controleTarefa;
    final recorrente =
        widget.tarefa?.serieIdentificador != null &&
        controle is OperacoesRecorrencia;
    final alcance = recorrente ? await _escolherAlcance(excluir: false) : null;
    if (!mounted || (recorrente && alcance == null)) return;
    final horario = _horarioSelecionado!;
    final tarefa = Tarefa(
      titulo: _tituloController.text,
      descricao: _textoOpcional(_descricaoController),
      data: _dataSelecionada,
      horario: HorarioTarefa(hora: horario.hour, minuto: horario.minute),
      duracaoEstimada: Duration(
        minutes: int.parse(_duracaoController.text.trim()),
      ),
      tempoRegistrado: widget.tarefa?.tempoRegistrado ?? Duration.zero,
      prioridade: _prioridade,
      repeticao: _repeticao,
      categoria: _textoOpcional(_categoriaController),
      status: widget.tarefa?.status ?? StatusTarefa.pendente,
      lembreteAtivo: _lembreteAtivo,
      antecedenciaLembrete: Duration(minutes: _antecedenciaMinutos),
    );

    setState(() => _salvando = true);
    try {
      if (alcance != null && controle is OperacoesRecorrencia) {
        await (controle as OperacoesRecorrencia).editarOcorrencia(
          widget.tarefa!.identificador!,
          tarefa,
          alcance,
        );
      } else if (widget.estaEditando) {
        await widget.controleTarefa.editarTarefa(
          widget.tarefa!.identificador!,
          tarefa,
        );
      } else {
        await widget.controleTarefa.criarTarefa(tarefa);
      }
      if (mounted) {
        final mensagem = _mensagemResultadoLembrete();
        final mensageiro = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        if (mensagem != null) {
          mensageiro.showSnackBar(SnackBar(content: Text(mensagem)));
        }
      }
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erroOperacao = _mensagemDoErro(erro, acao: 'salvar');
      });
    }
  }

  Future<AlcanceRecorrencia?> _escolherAlcance({required bool excluir}) {
    final mudouRepeticao = !excluir && _repeticao != widget.tarefa?.repeticao;
    return showDialog<AlcanceRecorrencia>(
      context: context,
      builder: (contexto) => SimpleDialog(
        title: Text(
          excluir
              ? 'Excluir ocorrências?'
              : 'Salvar alterações em quais tarefas?',
        ),
        children: [
          if (mudouRepeticao)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Mudar a repetição também afeta as próximas ocorrências.',
              ),
            ),
          if (!mudouRepeticao)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(contexto, AlcanceRecorrencia.somenteEsta),
              child: const Text('Somente esta ocorrência'),
            ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(contexto, AlcanceRecorrencia.estaEProximas),
            child: const Text('Esta e as próximas'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _excluir() async {
    if (_salvando) return;
    final controle = widget.controleTarefa;
    final recorrente =
        widget.tarefa?.serieIdentificador != null &&
        controle is OperacoesRecorrencia;
    final alcance = recorrente ? await _escolherAlcance(excluir: true) : null;
    if (!mounted || (recorrente && alcance == null)) return;
    final confirmou =
        recorrente ||
        await showDialog<bool>(
              context: context,
              builder: (contextoDialogo) => AlertDialog(
                title: const Text('Excluir tarefa?'),
                content: const Text(
                  'Esta ação remove a tarefa salva e não pode ser desfeita.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(contextoDialogo).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(contextoDialogo).pop(true),
                    child: const Text('Excluir'),
                  ),
                ],
              ),
            ) ==
            true;
    if (!confirmou || !mounted) return;

    setState(() {
      _salvando = true;
      _erroOperacao = null;
    });
    try {
      final id = widget.tarefa!.identificador!;
      if (alcance != null && controle is OperacoesRecorrencia) {
        await (controle as OperacoesRecorrencia).excluirOcorrencia(id, alcance);
      } else {
        await controle.excluirTarefa(id);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erroOperacao = _mensagemDoErro(erro, acao: 'excluir');
      });
    }
  }

  String _mensagemDoErro(Object erro, {required String acao}) {
    if (erro is ValidacaoTarefaException) return erro.mensagem;
    if (erro is TarefaNaoEncontradaException) {
      return 'A tarefa não foi encontrada. Atualize a lista e tente novamente.';
    }
    if (kIsWeb) {
      return 'O armazenamento de tarefas não está disponível no navegador.';
    }
    return 'Não foi possível $acao a tarefa. Tente novamente.';
  }

  String? _mensagemResultadoLembrete() {
    if (!_lembreteAtivo) return null;
    final controle = widget.controleTarefa;
    if (controle is! OperacoesLembreteTarefa) {
      return 'Tarefa salva, mas não foi possível confirmar o agendamento.';
    }
    final operacoesLembrete = controle as OperacoesLembreteTarefa;
    return switch (operacoesLembrete.ultimoResultadoAgendamento) {
      ResultadoAgendamentoLembrete.agendadoComPossivelAtraso =>
        'Lembrete agendado. O Android pode atrasar um pouco a entrega.',
      ResultadoAgendamentoLembrete.horarioAusente =>
        'Tarefa salva sem agendamento: defina um horário para o lembrete.',
      ResultadoAgendamentoLembrete.horarioPassado =>
        'Tarefa salva sem agendamento: o horário do lembrete já passou.',
      ResultadoAgendamentoLembrete.permissaoNegada =>
        'Tarefa salva sem agendamento: permita notificações em Perfil.',
      ResultadoAgendamentoLembrete.indisponivel =>
        'Tarefa salva sem agendamento: notificações não estão disponíveis.',
      ResultadoAgendamentoLembrete.falha ||
      null => 'Tarefa salva, mas não foi possível agendar o lembrete.',
      ResultadoAgendamentoLembrete.desativado ||
      ResultadoAgendamentoLembrete.tarefaConcluida => null,
    };
  }

  String? get _avisoLembrete {
    if (!_lembreteAtivo) return null;
    final horario = _horarioSelecionado;
    if (horario == null) {
      return 'Defina um horário para poder salvar e agendar o lembrete.';
    }
    final instante = DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month,
      _dataSelecionada.day,
      horario.hour,
      horario.minute,
    ).subtract(Duration(minutes: _antecedenciaMinutos));
    if (!instante.isAfter(widget.relogio())) {
      return 'Esse lembrete ficaria no passado. A tarefa será salva sem agendamento.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      backgroundColor: CoresApp.fundo,
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.estaEditando ? 'Editar tarefa' : 'Nova tarefa'),
            const Text(
              'Reserve tempo para o que importa',
              style: TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
            key: _chaveFormulario,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CampoTexto(
                    key: const Key('campo_titulo'),
                    rotulo: 'Título',
                    controller: _tituloController,
                    habilitado: !_salvando,
                    autofocus: !widget.estaEditando,
                    acaoTeclado: TextInputAction.next,
                    validator: _validarTitulo,
                    modoAutovalidacao: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 12),
                  CampoTexto(
                    key: const Key('campo_descricao'),
                    rotulo: 'Descrição',
                    controller: _descricaoController,
                    habilitado: !_salvando,
                    minLinhas: 3,
                    maxLinhas: 5,
                    tipoTeclado: TextInputType.multiline,
                    acaoTeclado: TextInputAction.newline,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CampoTexto(
                          key: const Key('campo_data'),
                          rotulo: 'Data',
                          controller: _dataController,
                          habilitado: !_salvando,
                          somenteLeitura: true,
                          onTap: _selecionarData,
                          iconeSufixo: Icons.calendar_today_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CampoTexto(
                          key: const Key('campo_horario'),
                          rotulo: 'Horário',
                          controller: _horarioController,
                          habilitado: !_salvando,
                          somenteLeitura: true,
                          onTap: _selecionarHorario,
                          iconeSufixo: Icons.schedule_outlined,
                          validator: _validarHorario,
                          modoAutovalidacao: AutovalidateMode.onUserInteraction,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CampoTexto(
                          key: const Key('campo_duracao'),
                          rotulo: 'Duração (minutos)',
                          controller: _duracaoController,
                          habilitado: !_salvando,
                          tipoTeclado: TextInputType.number,
                          acaoTeclado: TextInputAction.next,
                          formatadores: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: _validarDuracao,
                          modoAutovalidacao: AutovalidateMode.onUserInteraction,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CampoTexto(
                          key: const Key('campo_categoria'),
                          rotulo: 'Categoria',
                          controller: _categoriaController,
                          habilitado: !_salvando,
                          acaoTeclado: TextInputAction.done,
                          onSubmitted: (_) => _salvar(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Prioridade', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: PrioridadeTarefa.values.map((prioridade) {
                      final selecionada = prioridade == _prioridade;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: prioridade == PrioridadeTarefa.alta ? 0 : 8,
                          ),
                          child: ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                _rotuloPrioridade(prioridade),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            selected: selecionada,
                            onSelected: _salvando
                                ? null
                                : (_) =>
                                      setState(() => _prioridade = prioridade),
                            selectedColor: _fundoPrioridade(prioridade),
                            backgroundColor: _fundoPrioridade(prioridade),
                            side: BorderSide(
                              color: selecionada
                                  ? _corPrioridade(prioridade)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                            labelStyle: TextStyle(
                              color: _corPrioridade(prioridade),
                              fontWeight: FontWeight.w600,
                            ),
                            showCheckmark: selecionada,
                            checkmarkColor: _corPrioridade(prioridade),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  DropdownButtonFormField<RepeticaoTarefa>(
                    key: const Key('repeticao_tarefa'),
                    initialValue: _repeticao,
                    decoration: const InputDecoration(labelText: 'Repetição'),
                    items: const [
                      DropdownMenuItem(
                        value: RepeticaoTarefa.nenhuma,
                        child: Text('Sem repetição'),
                      ),
                      DropdownMenuItem(
                        value: RepeticaoTarefa.diaria,
                        child: Text('Diária'),
                      ),
                      DropdownMenuItem(
                        value: RepeticaoTarefa.semanal,
                        child: Text('Semanal'),
                      ),
                    ],
                    onChanged: _salvando
                        ? null
                        : (valor) {
                            if (valor != null) {
                              setState(() => _repeticao = valor);
                            }
                          },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Quando lembrar?',
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const Key('ativar_lembrete_individual'),
                          value: _lembreteAtivo,
                          onChanged: _salvando
                              ? null
                              : (valor) =>
                                    setState(() => _lembreteAtivo = valor),
                          secondary: const Icon(
                            Icons.alarm_outlined,
                            color: CoresApp.principal,
                          ),
                          title: const Text(
                            'Lembrete individual',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Ative somente para esta tarefa',
                          ),
                        ),
                        if (_lembreteAtivo) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: DropdownButtonFormField<int>(
                              key: const Key('antecedencia_lembrete'),
                              initialValue: _antecedenciaMinutos,
                              decoration: const InputDecoration(
                                labelText: 'Antecedência',
                                prefixIcon: Icon(Icons.schedule_outlined),
                              ),
                              items: _opcoesAntecedencia
                                  .map(
                                    (minutos) => DropdownMenuItem<int>(
                                      value: minutos,
                                      child: Text(_rotuloAntecedencia(minutos)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _salvando
                                  ? null
                                  : (valor) {
                                      if (valor != null) {
                                        setState(
                                          () => _antecedenciaMinutos = valor,
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_avisoLembrete != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: const Key('aviso_lembrete_nao_agendado'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CoresApp.principalSuave,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: CoresApp.principal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_avisoLembrete!)),
                        ],
                      ),
                    ),
                  ],
                  if (_erroOperacao != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CoresApp.atrasadaFundo,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CoresApp.erro),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: CoresApp.erro,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _erroOperacao!,
                              style: const TextStyle(color: CoresApp.erro),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Botao(
                    texto: widget.estaEditando
                        ? 'Salvar alterações'
                        : 'Salvar tarefa',
                    textoCarregando: 'Salvando...',
                    icone: Icons.check_rounded,
                    carregando: _salvando,
                    onPressed: _salvar,
                  ),
                  if (widget.estaEditando) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _salvando ? null : _excluir,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Excluir tarefa'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CoresApp.erro,
                          minimumSize: const Size(48, 50),
                          side: const BorderSide(color: CoresApp.erro),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _rotuloPrioridade(PrioridadeTarefa prioridade) {
    return switch (prioridade) {
      PrioridadeTarefa.baixa => 'Baixa',
      PrioridadeTarefa.media => 'Média',
      PrioridadeTarefa.alta => 'Alta',
    };
  }

  List<int> get _opcoesAntecedencia {
    final opcoes = <int>{0, 5, 15, 30, 60, 120, _antecedenciaMinutos}.toList()
      ..sort();
    return opcoes;
  }

  String _rotuloAntecedencia(int minutos) {
    if (minutos == 0) return 'No horário';
    if (minutos == 60) return '1 hora antes';
    if (minutos == 120) return '2 horas antes';
    return '$minutos minutos antes';
  }

  Color _corPrioridade(PrioridadeTarefa prioridade) {
    return switch (prioridade) {
      PrioridadeTarefa.baixa => CoresApp.prioridadeBaixa,
      PrioridadeTarefa.media => CoresApp.prioridadeMedia,
      PrioridadeTarefa.alta => CoresApp.prioridadeAlta,
    };
  }

  Color _fundoPrioridade(PrioridadeTarefa prioridade) {
    return switch (prioridade) {
      PrioridadeTarefa.baixa => CoresApp.prioridadeBaixaFundo,
      PrioridadeTarefa.media => CoresApp.prioridadeMediaFundo,
      PrioridadeTarefa.alta => CoresApp.prioridadeAltaFundo,
    };
  }
}
