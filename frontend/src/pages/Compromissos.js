import React, { useState, useEffect } from 'react';
import {
  Container,
  Typography,
  Button,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  IconButton,
  Snackbar,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  FormControlLabel,
  Switch,
  Box,
  Chip,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Repeat as RepeatIcon,
} from '@mui/icons-material';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns';
import { LocalizationProvider, DatePicker, TimePicker } from '@mui/x-date-pickers';
import ptBR from 'date-fns/locale/pt-BR';
import { format, parse } from 'date-fns';
import axios from 'axios';
import { API_CONFIG } from '../config';

const API_URL = API_CONFIG.baseURL;

const diasSemana = [
  { value: 0, label: 'Segunda' },
  { value: 1, label: 'Terça' },
  { value: 2, label: 'Quarta' },
  { value: 3, label: 'Quinta' },
  { value: 4, label: 'Sexta' },
  { value: 5, label: 'Sábado' },
  { value: 6, label: 'Domingo' },
];

function Compromissos() {
  const [compromissos, setCompromissos] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingCompromisso, setEditingCompromisso] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '' });
  const [filtroPeriodo, setFiltroPeriodo] = useState('todos');
  
  const [formData, setFormData] = useState({
    titulo: '',
    data: new Date(),
    hora_inicio: new Date(),
    hora_fim: new Date(),
    descricao: '',
    participantes: [],
    is_recorrente: false,
    tipo_recorrencia: 'diaria',
    dias_semana: [],
    data_fim_recorrencia: new Date(),
  });

  useEffect(() => {
    fetchCompromissos();
  }, [filtroPeriodo]);

  const fetchCompromissos = async () => {
    try {
      const response = await axios.get(`${API_URL}/compromissos/`, {
        params: { periodo: filtroPeriodo === 'todos' ? null : filtroPeriodo },
      });
      setCompromissos(response.data);
    } catch (error) {
      console.error('Erro ao buscar compromissos:', error);
      setSnackbar({
        open: true,
        message: 'Erro ao carregar compromissos',
      });
    }
  };

  const handleOpenDialog = (compromisso = null) => {
    if (compromisso) {
      setEditingCompromisso(compromisso);
      setFormData({
        ...compromisso,
        data: parse(compromisso.data, 'dd/MM/yyyy', new Date()),
        hora_inicio: parse(compromisso.hora_inicio, 'HH:mm', new Date()),
        hora_fim: compromisso.hora_fim
          ? parse(compromisso.hora_fim, 'HH:mm', new Date())
          : new Date(),
        is_recorrente: !!compromisso.recorrencia,
        tipo_recorrencia: compromisso.recorrencia?.tipo || 'diaria',
        dias_semana: compromisso.recorrencia?.dias_semana || [],
        data_fim_recorrencia: compromisso.recorrencia
          ? parse(compromisso.recorrencia.ate_data, 'dd/MM/yyyy', new Date())
          : new Date(),
      });
    } else {
      setEditingCompromisso(null);
      setFormData({
        titulo: '',
        data: new Date(),
        hora_inicio: new Date(),
        hora_fim: new Date(),
        descricao: '',
        participantes: [],
        is_recorrente: false,
        tipo_recorrencia: 'diaria',
        dias_semana: [],
        data_fim_recorrencia: new Date(),
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingCompromisso(null);
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleSubmit = async () => {
    try {
      const compromissoData = {
        titulo: formData.titulo,
        data: format(formData.data, 'dd/MM/yyyy'),
        hora_inicio: format(formData.hora_inicio, 'HH:mm'),
        hora_fim: format(formData.hora_fim, 'HH:mm'),
        descricao: formData.descricao,
        participantes: formData.participantes,
      };

      if (formData.is_recorrente) {
        compromissoData.recorrencia = {
          tipo: formData.tipo_recorrencia,
          ate_data: format(formData.data_fim_recorrencia, 'dd/MM/yyyy'),
        };

        if (formData.tipo_recorrencia === 'dias_especificos') {
          compromissoData.recorrencia.dias_semana = formData.dias_semana;
        }
      }

      if (editingCompromisso) {
        await axios.put(
          `${API_URL}/compromissos/${editingCompromisso.id}`,
          compromissoData
        );
        setSnackbar({
          open: true,
          message: 'Compromisso atualizado com sucesso!',
        });
      } else {
        await axios.post(`${API_URL}/compromissos/`, compromissoData);
        setSnackbar({
          open: true,
          message: 'Compromisso adicionado com sucesso!',
        });
      }
      handleCloseDialog();
      fetchCompromissos();
    } catch (error) {
      console.error('Erro ao salvar compromisso:', error);
      setSnackbar({
        open: true,
        message: 'Erro ao salvar compromisso',
      });
    }
  };

  const handleDelete = async (id, recorrencia) => {
    let excluirSerie = false;
    if (recorrencia) {
      excluirSerie = window.confirm(
        'Este é um compromisso recorrente. Deseja excluir toda a série?'
      );
    }

    try {
      await axios.delete(`${API_URL}/compromissos/${id}`, {
        params: { excluir_serie: excluirSerie },
      });
      setSnackbar({
        open: true,
        message: 'Compromisso excluído com sucesso!',
      });
      fetchCompromissos();
    } catch (error) {
      console.error('Erro ao excluir compromisso:', error);
      setSnackbar({
        open: true,
        message: 'Erro ao excluir compromisso',
      });
    }
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
        <Typography variant="h4">Compromissos</Typography>
        <FormControl sx={{ minWidth: 200 }}>
          <InputLabel>Filtrar por período</InputLabel>
          <Select
            value={filtroPeriodo}
            label="Filtrar por período"
            onChange={(e) => setFiltroPeriodo(e.target.value)}
          >
            <MenuItem value="todos">Todos</MenuItem>
            <MenuItem value="hoje">Hoje</MenuItem>
            <MenuItem value="semana">Próxima semana</MenuItem>
            <MenuItem value="mes">Próximo mês</MenuItem>
          </Select>
        </FormControl>
      </Box>

      <Button
        variant="contained"
        color="primary"
        startIcon={<AddIcon />}
        onClick={() => handleOpenDialog()}
        sx={{ mb: 3 }}
      >
        Novo Compromisso
      </Button>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Título</TableCell>
              <TableCell>Data</TableCell>
              <TableCell>Horário</TableCell>
              <TableCell>Descrição</TableCell>
              <TableCell>Participantes</TableCell>
              <TableCell>Recorrência</TableCell>
              <TableCell>Ações</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {compromissos.map((compromisso) => (
              <TableRow key={compromisso.id}>
                <TableCell>{compromisso.titulo}</TableCell>
                <TableCell>{compromisso.data}</TableCell>
                <TableCell>
                  {compromisso.hora_inicio} - {compromisso.hora_fim}
                </TableCell>
                <TableCell>{compromisso.descricao}</TableCell>
                <TableCell>
                  {compromisso.participantes?.map((p) => (
                    <Chip key={p} label={p} size="small" sx={{ mr: 0.5 }} />
                  ))}
                </TableCell>
                <TableCell>
                  {compromisso.recorrencia && (
                    <Chip
                      icon={<RepeatIcon />}
                      label={compromisso.recorrencia.tipo}
                      color="primary"
                      size="small"
                    />
                  )}
                </TableCell>
                <TableCell>
                  <IconButton
                    color="primary"
                    onClick={() => handleOpenDialog(compromisso)}
                  >
                    <EditIcon />
                  </IconButton>
                  <IconButton
                    color="error"
                    onClick={() => handleDelete(compromisso.id, compromisso.recorrencia)}
                  >
                    <DeleteIcon />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingCompromisso ? 'Editar Compromisso' : 'Novo Compromisso'}
        </DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            name="titulo"
            label="Título"
            type="text"
            fullWidth
            value={formData.titulo}
            onChange={handleInputChange}
          />

          <LocalizationProvider dateAdapter={AdapterDateFns} adapterLocale={ptBR}>
            <Box sx={{ display: 'flex', gap: 2, my: 2 }}>
              <DatePicker
                label="Data"
                value={formData.data}
                onChange={(newValue) =>
                  setFormData((prev) => ({ ...prev, data: newValue }))
                }
              />
              <TimePicker
                label="Hora de início"
                value={formData.hora_inicio}
                onChange={(newValue) =>
                  setFormData((prev) => ({ ...prev, hora_inicio: newValue }))
                }
              />
              <TimePicker
                label="Hora de término"
                value={formData.hora_fim}
                onChange={(newValue) =>
                  setFormData((prev) => ({ ...prev, hora_fim: newValue }))
                }
              />
            </Box>
          </LocalizationProvider>

          <TextField
            margin="dense"
            name="descricao"
            label="Descrição"
            type="text"
            fullWidth
            multiline
            rows={3}
            value={formData.descricao}
            onChange={handleInputChange}
          />

          <TextField
            margin="dense"
            name="participantes"
            label="Participantes (separados por vírgula)"
            type="text"
            fullWidth
            value={formData.participantes.join(', ')}
            onChange={(e) =>
              setFormData((prev) => ({
                ...prev,
                participantes: e.target.value.split(',').map((p) => p.trim()),
              }))
            }
          />

          <FormControlLabel
            control={
              <Switch
                checked={formData.is_recorrente}
                onChange={(e) =>
                  setFormData((prev) => ({
                    ...prev,
                    is_recorrente: e.target.checked,
                  }))
                }
              />
            }
            label="Compromisso recorrente"
            sx={{ mt: 2 }}
          />

          {formData.is_recorrente && (
            <Box sx={{ mt: 2 }}>
              <FormControl fullWidth sx={{ mb: 2 }}>
                <InputLabel>Tipo de recorrência</InputLabel>
                <Select
                  value={formData.tipo_recorrencia}
                  label="Tipo de recorrência"
                  onChange={(e) =>
                    setFormData((prev) => ({
                      ...prev,
                      tipo_recorrencia: e.target.value,
                    }))
                  }
                >
                  <MenuItem value="diaria">Diária</MenuItem>
                  <MenuItem value="semanal">Semanal</MenuItem>
                  <MenuItem value="dias_especificos">Dias específicos</MenuItem>
                  <MenuItem value="mensal">Mensal</MenuItem>
                </Select>
              </FormControl>

              {formData.tipo_recorrencia === 'dias_especificos' && (
                <FormControl fullWidth sx={{ mb: 2 }}>
                  <InputLabel>Dias da semana</InputLabel>
                  <Select
                    multiple
                    value={formData.dias_semana}
                    label="Dias da semana"
                    onChange={(e) =>
                      setFormData((prev) => ({
                        ...prev,
                        dias_semana: e.target.value,
                      }))
                    }
                    renderValue={(selected) =>
                      selected
                        .map(
                          (value) =>
                            diasSemana.find((dia) => dia.value === value)?.label
                        )
                        .join(', ')
                    }
                  >
                    {diasSemana.map((dia) => (
                      <MenuItem key={dia.value} value={dia.value}>
                        {dia.label}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              )}

              <LocalizationProvider
                dateAdapter={AdapterDateFns}
                adapterLocale={ptBR}
              >
                <DatePicker
                  label="Repetir até"
                  value={formData.data_fim_recorrencia}
                  onChange={(newValue) =>
                    setFormData((prev) => ({
                      ...prev,
                      data_fim_recorrencia: newValue,
                    }))
                  }
                />
              </LocalizationProvider>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancelar</Button>
          <Button onClick={handleSubmit} variant="contained" color="primary">
            Salvar
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={6000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
        message={snackbar.message}
      />
    </Container>
  );
}

export default Compromissos; 