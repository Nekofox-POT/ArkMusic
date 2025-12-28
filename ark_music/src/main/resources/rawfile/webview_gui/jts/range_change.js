document.addEventListener('DOMContentLoaded', () => {

    const play_range = document.getElementById('song_playing');

    play_range.addEventListener('input', function() {
        arkts.change_times(play_range.value);
});

});