package com.example.pisid.fragments;

import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.GridLayout;
import android.widget.TextView;
import androidx.fragment.app.Fragment;
import com.android.volley.Request;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.HashMap;
import java.util.Map;

public class MazeHeatMapFragment extends Fragment {
    private GridLayout gridRooms;
    private Handler handler = new Handler();
    private Map<Integer, TextView> roomViews = new HashMap<>();

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_maze_heatmap, container, false);
        gridRooms = view.findViewById(R.id.grid_rooms);

        setupMazeGrid();
        startRealTimeUpdate();
        return view;
    }

    private void setupMazeGrid() {
        // Criar 9 salas (exemplo 3x3)
        for (int i = 1; i <= 9; i++) {
            TextView room = new TextView(getContext());
            room.setText("Sala " + i);
            room.setPadding(30, 80, 30, 80);
            room.setGravity(17); // Center
            room.setBackgroundColor(Color.parseColor("#2C2C2C")); // Cor inicial: Cinza escuro
            room.setTextColor(Color.WHITE);

            GridLayout.LayoutParams params = new GridLayout.LayoutParams();
            params.width = 0;
            params.height = GridLayout.LayoutParams.WRAP_CONTENT;
            params.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f);
            params.setMargins(8, 8, 8, 8);
            room.setLayoutParams(params);

            gridRooms.addView(room);
            roomViews.put(i, room);
        }
    }

    private void startRealTimeUpdate() {
        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                fetchHeatMapData();
                handler.postDelayed(this, 1000); // Atualiza a cada 1 segundo
            }
        }, 1000);
    }

    private void fetchHeatMapData() {
        String url = "http://10.0.2.2:9000/App/Php/get_realtime_heatmap.php";
        StringRequest request = new StringRequest(Request.Method.GET, url, response -> {
            try {
                JSONArray array = new JSONArray(response);
                for (int i = 0; i < array.length(); i++) {
                    JSONObject obj = array.getJSONObject(i);
                    int salaId = obj.getInt("sala");
                    int intensidade = obj.getInt("intensidade");

                    if (roomViews.containsKey(salaId)) {
                        updateRoomColor(roomViews.get(salaId), intensidade);
                    }
                }
            } catch (Exception e) { e.printStackTrace(); }
        }, null);
        Volley.newRequestQueue(getContext()).add(request);
    }

    private void updateRoomColor(TextView view, int intensity) {
        // Lógica de Cor (Heat Map)
        if (intensity == 0) view.setBackgroundColor(Color.parseColor("#2C2C2C")); // Sem tráfego
        else if (intensity < 5) view.setBackgroundColor(Color.parseColor("#00BCD4")); // Ciano (Frio)
        else if (intensity < 15) view.setBackgroundColor(Color.parseColor("#FFC107")); // Amarelo (Morno)
        else view.setBackgroundColor(Color.parseColor("#F44336")); // Vermelho (Quente!)
    }
}