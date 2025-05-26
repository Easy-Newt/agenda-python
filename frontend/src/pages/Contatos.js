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
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
} from '@mui/icons-material';
import axios from 'axios';

const API_URL = 'http://localhost:8000/api';

function Contatos() {
  const [contatos, setContatos] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingContato, setEditingContato] = useState(null);
  const [formData, setFormData] = useState({
    nome: '',
    telefone: '',
    email: '',
    endereco: '',
  });
  const [snackbar, setSnackbar] = useState({ open: false, message: '' });

  useEffect(() => {
    fetchContatos();
  }, []);

  const fetchContatos = async () => {
    try {
      const response = await axios.get(`${API_URL}/contatos/`);
      setContatos(response.data);
    } catch (error) {
      console.error('Erro ao buscar contatos:', error);
      setSnackbar({
        open: true,
        message: 'Erro ao carregar contatos',
      });
    }
  };

  const handleOpenDialog = (contato = null) => {
    if (contato) {
      setEditingContato(contato);
      setFormData(contato);
    } else {
      setEditingContato(null);
      setFormData({
        nome: '',
        telefone: '',
        email: '',
        endereco: '',
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingContato(null);
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
      if (editingContato) {
        await axios.put(
          `${API_URL}/contatos/${editingContato.id}`,
          formData
        );
        setSnackbar({
          open: true,
          message: 'Contato atualizado com sucesso!',
        });
      } else {
        await axios.post(`${API_URL}/contatos/`, formData);
        setSnackbar({
          open: true,
          message: 'Contato adicionado com sucesso!',
        });
      }
      handleCloseDialog();
      fetchContatos();
    } catch (error) {
      console.error('Erro ao salvar contato:', error);
      setSnackbar({
        open: true,
        message: 'Erro ao salvar contato',
      });
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm('Tem certeza que deseja excluir este contato?')) {
      try {
        await axios.delete(`${API_URL}/contatos/${id}`);
        setSnackbar({
          open: true,
          message: 'Contato excluído com sucesso!',
        });
        fetchContatos();
      } catch (error) {
        console.error('Erro ao excluir contato:', error);
        setSnackbar({
          open: true,
          message: 'Erro ao excluir contato',
        });
      }
    }
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4 }}>
      <Typography variant="h4" gutterBottom>
        Contatos
      </Typography>
      <Button
        variant="contained"
        color="primary"
        startIcon={<AddIcon />}
        onClick={() => handleOpenDialog()}
        sx={{ mb: 3 }}
      >
        Novo Contato
      </Button>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Nome</TableCell>
              <TableCell>Telefone</TableCell>
              <TableCell>Email</TableCell>
              <TableCell>Endereço</TableCell>
              <TableCell>Ações</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {contatos.map((contato) => (
              <TableRow key={contato.id}>
                <TableCell>{contato.nome}</TableCell>
                <TableCell>{contato.telefone}</TableCell>
                <TableCell>{contato.email}</TableCell>
                <TableCell>{contato.endereco}</TableCell>
                <TableCell>
                  <IconButton
                    color="primary"
                    onClick={() => handleOpenDialog(contato)}
                  >
                    <EditIcon />
                  </IconButton>
                  <IconButton
                    color="error"
                    onClick={() => handleDelete(contato.id)}
                  >
                    <DeleteIcon />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      <Dialog open={openDialog} onClose={handleCloseDialog}>
        <DialogTitle>
          {editingContato ? 'Editar Contato' : 'Novo Contato'}
        </DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            name="nome"
            label="Nome"
            type="text"
            fullWidth
            value={formData.nome}
            onChange={handleInputChange}
          />
          <TextField
            margin="dense"
            name="telefone"
            label="Telefone"
            type="text"
            fullWidth
            value={formData.telefone}
            onChange={handleInputChange}
          />
          <TextField
            margin="dense"
            name="email"
            label="Email"
            type="email"
            fullWidth
            value={formData.email}
            onChange={handleInputChange}
          />
          <TextField
            margin="dense"
            name="endereco"
            label="Endereço"
            type="text"
            fullWidth
            value={formData.endereco}
            onChange={handleInputChange}
          />
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

export default Contatos; 