import React from 'react';
import { Link as RouterLink } from 'react-router-dom';
import {
  AppBar,
  Toolbar,
  Typography,
  Button,
  Box,
} from '@mui/material';
import {
  Home as HomeIcon,
  ContactPhone as ContactIcon,
  Event as EventIcon,
} from '@mui/icons-material';

function Navbar() {
  return (
    <AppBar position="static">
      <Toolbar>
        <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
          Agenda
        </Typography>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <Button
            color="inherit"
            component={RouterLink}
            to="/"
            startIcon={<HomeIcon />}
          >
            Home
          </Button>
          <Button
            color="inherit"
            component={RouterLink}
            to="/contatos"
            startIcon={<ContactIcon />}
          >
            Contatos
          </Button>
          <Button
            color="inherit"
            component={RouterLink}
            to="/compromissos"
            startIcon={<EventIcon />}
          >
            Compromissos
          </Button>
        </Box>
      </Toolbar>
    </AppBar>
  );
}

export default Navbar; 