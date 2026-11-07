import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../control/control_tarefa.dart';
import '../model/tarefa.dart';
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
  });

  final OperacoesTarefa controleTarefa;
  final Tarefa? tarefa;
  final DateTime? dataInicial;

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
  bool _salvando = false;
  String? _erroOperacao;

  @override
  void initState() {
    super.initState();
    final tarefa = widget.tarefa;
    _dataSelecionada = tarefa?.data ?? widget.dataInicial ?? DateTime.now();
    _horarioSelecionado = tarefa?.horario == null
        ? (widget.estaEditando ? null : TimeOfDay.now())
        : TimeOfDay(
            hour: tarefa!.horario!.hora,
            minute: tarefa.horario!.minuto,
          );
    _prioridade = tarefa?.prioridade ?? PrioridadeTarefa.media;

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
      initialTime: _horarioSelecionado ?? TimeOfDay.now(),
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
      categoria: _textoOpcional(_categoriaController),
      status: widget.tarefa?.status ?? StatusTarefa.pendente,
    );

    setState(() => _salvando = true);
    try {
      if (widget.estaEditando) {
        await widget.controleTarefa.editarTarefa(
          widget.tarefa!.identificador!,
          tarefa,
        );
      } else {
        await widget.controleTarefa.criarTarefa(tarefa);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erroOperacao = _mensagemDoErro(erro, acao: 'salvar');
      });
    }
  }

  Future<void> _excluir() async {
    if (_salvando) return;
    final confirmou = await showDialog<bool>(
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
    );
    if (confirmou != true || !mounted) return;

    setState(() {
      _salvando = true;
      _erroOperacao = null;
    });
    try {
      await widget.controleTarefa.excluirTarefa(widget.tarefa!.identificador!);
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
