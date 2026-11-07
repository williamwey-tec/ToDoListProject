import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../control/control_tarefa.dart';
import '../model/tarefa.dart';
import '../tema/cores.dart';
import 'tela_tarefa.dart';

/// Acesso auxiliar a todas as tarefas persistidas no dispositivo.
class TelaTarefasSalvas extends StatefulWidget {
  const TelaTarefasSalvas({
    super.key,
    required this.controleTarefa,
    this.onTarefasAlteradas,
  });

  final OperacoesTarefa controleTarefa;
  final VoidCallback? onTarefasAlteradas;

  @override
  State<TelaTarefasSalvas> createState() => _TelaTarefasSalvasState();
}

class _TelaTarefasSalvasState extends State<TelaTarefasSalvas> {
  List<Tarefa> _tarefas = const [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final tarefas = await widget.controleTarefa.consultarTarefasPorIntervalo(
        DateTime(1, 1, 1),
        DateTime(9998, 12, 31),
      );
      if (!mounted) return;
      setState(() {
        _tarefas = tarefas;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = kIsWeb
            ? 'O armazenamento de tarefas não está disponível no navegador.'
            : 'Não foi possível consultar as tarefas salvas.';
      });
    }
  }

  Future<void> _abrir(Tarefa tarefa) async {
    final alterou = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            TelaTarefa(controleTarefa: widget.controleTarefa, tarefa: tarefa),
      ),
    );
    if (alterou == true && mounted) {
      widget.onTarefasAlteradas?.call();
      await _carregar();
    }
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  String _formatarHorario(HorarioTarefa? horario) {
    if (horario == null) return 'Sem horário';
    final hora = horario.hora.toString().padLeft(2, '0');
    final minuto = horario.minuto.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoresApp.fundo,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tarefas salvas'),
            Text(
              'Registros persistidos no dispositivo',
              style: TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(onRefresh: _carregar, child: _construirConteudo()),
    );
  }

  Widget _construirConteudo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.storage_outlined, size: 44, color: CoresApp.erro),
          const SizedBox(height: 12),
          Text(
            _erro!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CoresApp.erro),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ),
        ],
      );
    }
    if (_tarefas.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(
            Icons.inventory_2_outlined,
            size: 44,
            color: CoresApp.textoSecundario,
          ),
          SizedBox(height: 12),
          Text(
            'Nenhuma tarefa salva.',
            textAlign: TextAlign.center,
            style: TextStyle(color: CoresApp.textoSecundario),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      itemCount: _tarefas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, indice) {
        final tarefa = _tarefas[indice];
        final duracao = tarefa.duracaoEstimada?.inMinutes;
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              tarefa.titulo,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${_formatarData(tarefa.data)} · '
              '${_formatarHorario(tarefa.horario)}'
              '${duracao == null ? '' : ' · $duracao min'}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _abrir(tarefa),
          ),
        );
      },
    );
  }
}
