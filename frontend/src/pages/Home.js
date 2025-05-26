import React from 'react';
import { Container, Typography, Paper, Grid, Button } from '@mui/material';
import { useNavigate } from 'react-router-dom';
import { ContactPhone as ContactIcon, Event as EventIcon } from '@mui/icons-material';

function Home() {
  const navigate = useNavigate();

  return (
    <Container maxWidth="lg" sx={{ mt: 4 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        Bem-vindo à sua Agenda
      </Typography>
      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Paper
            sx={{
              p: 3,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              cursor: 'pointer',
              '&:hover': {
                backgroundColor: 'action.hover',
              },
            }}
            onClick={() => navigate('/contatos')}
          >
            <ContactIcon sx={{ fontSize: 60, color: 'primary.main', mb: 2 }} />
            <Typography variant="h5" gutterBottom>
              Contatos
            </Typography>
            <Typography variant="body1" color="text.secondary" align="center">
              Gerencie seus contatos, adicione novos, edite ou remova existentes.
            </Typography>
            <Button
              variant="contained"
              color="primary"
              sx={{ mt: 2 }}
              startIcon={<ContactIcon />}
            >
              Acessar Contatos
            </Button>
          </Paper>
        </Grid>
        <Grid item xs={12} md={6}>
          <Paper
            sx={{
              p: 3,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              cursor: 'pointer',
              '&:hover': {
                backgroundColor: 'action.hover',
              },
            }}
            onClick={() => navigate('/compromissos')}
          >
            <EventIcon sx={{ fontSize: 60, color: 'primary.main', mb: 2 }} />
            <Typography variant="h5" gutterBottom>
              Compromissos
            </Typography>
            <Typography variant="body1" color="text.secondary" align="center">
              Gerencie sua agenda, crie compromissos únicos ou recorrentes.
            </Typography>
            <Button
              variant="contained"
              color="primary"
              sx={{ mt: 2 }}
              startIcon={<EventIcon />}
            >
              Acessar Compromissos
            </Button>
          </Paper>
        </Grid>
      </Grid>
    </Container>
  );
}

export default Home; 